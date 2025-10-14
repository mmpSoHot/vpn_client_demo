import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/node_model.dart';
import 'singbox_manager.dart';

/// 节点延迟测试工具
/// 用于测试节点的响应速度（通过实际代理请求）
class NodeLatencyTester {
  static const String _testUrl = 'https://www.gstatic.com/generate_204';
  static const int _testPort = 18808; // 临时测试端口
  static const int _quickTimeoutSec = 3; // 快速探测超时
  static const int _fullTimeoutSec = 5;  // 全量代理测试超时
  static const int _maxFullTests = 5;    // 进入第二阶段全量测试的节点数量
  static const int _quickConcurrency = 8; // 快速探测并发

  /// 测试单个节点的延迟
  /// 返回延迟毫秒数，失败返回 -1
  static Future<int> testNodeLatency(NodeModel node) async {
    try {
      print('🔍 测试节点延迟: ${node.name}');

      // Step 1: 生成临时 sing-box 配置（使用不同端口避免冲突）
      await SingboxManager.generateConfigFromNode(
        node: node,
        mixedPort: _testPort,
      );

      // Step 2: 启动临时 sing-box 实例
      final process = await Process.start(
        SingboxManager.getSingboxPath(),
        ['run', '-c', SingboxManager.getConfigPath()],
        mode: ProcessStartMode.normal,
      );

      // 等待 sing-box 启动
      await Future.delayed(const Duration(milliseconds: 800));

      int latency = -1;

      try {
        // Step 3: 通过代理发送 HTTP 请求测试延迟
        final stopwatch = Stopwatch()..start();

        // 设置代理
        final httpClient = HttpClient()
          ..findProxy = (uri) => 'PROXY 127.0.0.1:$_testPort';

        final ioRequest = await httpClient.getUrl(Uri.parse(_testUrl));
        ioRequest.headers.set('User-Agent', 'Mozilla/5.0');

        final response = await ioRequest.close().timeout(
          Duration(seconds: _fullTimeoutSec),
        );

        stopwatch.stop();

        // 检查响应状态
        if (response.statusCode == 200 || response.statusCode == 204) {
          latency = stopwatch.elapsedMilliseconds;
          print('✅ ${node.name} 延迟: ${latency}ms');
        } else {
          print('❌ ${node.name} 响应异常: ${response.statusCode}');
        }

        httpClient.close();
      } catch (e) {
        print('❌ ${node.name} 连接测试失败: $e');
      }

      // Step 4: 停止临时 sing-box
      process.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 200));

      return latency;
    } catch (e) {
      print('❌ 测试 ${node.name} 延迟失败: $e');
      return -1;
    }
  }

  /// 测试多个节点的延迟（顺序测试，避免端口冲突）
  /// 返回 Map<节点名称, 延迟ms>
  static Future<Map<String, int>> testMultipleNodes(
      List<NodeModel> nodes) async {
    final results = <String, int>{};

    print('🔍 开始测试 ${nodes.length} 个节点...');

    // 第一阶段：快速 ICMP 探测（并发），得到粗略延迟
    final quickLatencies = <String, int>{};
    final futures = <Future<void>>[];
    int inflight = 0;
    for (final node in nodes) {
      final host = _extractHostFromRaw(node.rawConfig);
      if (host.isEmpty) {
        quickLatencies[node.name] = -1;
        continue;
      }
      // 控制并发
      if (inflight >= _quickConcurrency) {
        await Future.wait(futures);
        futures.clear();
        inflight = 0;
      }
      inflight++;
      futures.add(() async {
        final ms = await _quickICMPPing(host, timeoutSec: _quickTimeoutSec);
        quickLatencies[node.name] = ms;
      }());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    // 选出前 N 个进入第二阶段全量测试
    final candidates = [...nodes];
    candidates.sort((a, b) {
      final la = quickLatencies[a.name] ?? 1 << 30;
      final lb = quickLatencies[b.name] ?? 1 << 30;
      return la.compareTo(lb);
    });
    final topN = candidates.take(_maxFullTests).toList();

    print('⚡ 第一阶段完成，进入全量测试 Top ${topN.length} 个节点');

    // 第二阶段：顺序执行真实代理请求测试（更准确）
    for (final node in topN) {
      final latency = await testNodeLatency(node);
      results[node.name] = latency;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // 其余未进入全量测试的节点，回填快速延迟
    for (final node in nodes) {
      results.putIfAbsent(node.name, () => quickLatencies[node.name] ?? -1);
    }

    print('✅ 所有节点测试完成');
    return results;
  }

  /// 格式化延迟显示
  static String formatLatency(int latency) {
    if (latency < 0) {
      return '超时';
    } else if (latency == 0) {
      return '--';
    } else if (latency < 100) {
      return '${latency}ms'; // 绿色 - 优秀
    } else if (latency < 300) {
      return '${latency}ms'; // 黄色 - 良好
    } else {
      return '${latency}ms'; // 红色 - 较慢
    }
  }

  /// 根据延迟获取颜色
  static Color getLatencyColor(int latency) {
    if (latency < 0) {
      return const Color(0xFF999999); // 灰色 - 超时
    } else if (latency == 0) {
      return const Color(0xFF999999); // 灰色 - 未测试
    } else if (latency < 100) {
      return const Color(0xFF4CAF50); // 绿色 - 优秀
    } else if (latency < 300) {
      return const Color(0xFFFF9800); // 橙色 - 良好
    } else {
      return const Color(0xFFF44336); // 红色 - 较慢
    }
  }

  // ===================== 辅助方法 =====================

  /// 从原始配置中提取主机名
  static String _extractHostFromRaw(String raw) {
    try {
      final uri = Uri.parse(raw);
      return uri.host;
    } catch (_) {
      return '';
    }
  }

  /// 快速 ICMP 探测（不经过代理，粗略评估可达性）
  static Future<int> _quickICMPPing(String host, {int timeoutSec = 3}) async {
    try {
      final result = await Process.run(
        'ping',
        Platform.isWindows
            ? ['-n', '1', '-w', '${timeoutSec * 1000}', host]
            : ['-c', '1', '-W', '$timeoutSec', host],
        runInShell: true,
      ).timeout(Duration(seconds: timeoutSec + 1));

      if (result.exitCode != 0) return -1;
      final output = (result.stdout ?? '').toString();

      if (Platform.isWindows) {
        final m = RegExp(r'time[=<](\d+)ms|时间[=<](\d+)ms', caseSensitive: false)
            .firstMatch(output);
        if (m != null) {
          return int.tryParse(m.group(1) ?? m.group(2) ?? '0') ?? -1;
        }
      } else {
        final m = RegExp(r'time=(\d+\.?\d*)\s*ms').firstMatch(output);
        if (m != null) return double.parse(m.group(1)!).round();
      }
      return -1;
    } catch (_) {
      return -1;
    }
  }
}

