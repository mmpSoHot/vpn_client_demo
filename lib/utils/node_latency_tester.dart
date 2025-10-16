import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/node_model.dart';
import 'singbox_manager.dart';

/// 节点延迟测试工具
/// 根据协议类型智能选择测试方法（Hysteria2用ICMP Ping，其他用TCP）
class NodeLatencyTester {
  static const String _testUrl = 'https://www.gstatic.com/generate_204';
  static const int _testPort = 18808; // 临时测试端口
  static const int _fullTimeoutSec = 5;  // 全量代理测试超时

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

  /// 测试多个节点的延迟（快速并发 TCP 测试）
  /// 返回 Map<节点名称, 延迟ms>
  static Future<Map<String, int>> testMultipleNodes(
    List<NodeModel> nodes, {
    bool useFullTest = false, // 是否使用完整的代理测试（慢但准确）
  }) async {
    final results = <String, int>{};

    print('🔍 开始快速测试 ${nodes.length} 个节点...');

    // 根据协议类型选择测试方法（全并发）
    final futures = nodes.map((node) async {
      try {
        final host = _extractHostFromRaw(node.rawConfig);
        final port = _extractPortFromRaw(node.rawConfig);
        
        if (host.isEmpty || port <= 0) {
          print('❌ [${node.name}] 无效配置');
          return MapEntry(node.name, -1);
        }

        // 根据协议类型选择测试方法
        int latency = -1;
        final protocol = node.protocol.toLowerCase();
        
        if (protocol.contains('hysteria')) {
          // Hysteria2 使用 ICMP Ping（UDP 探测包服务器不响应）
          latency = await _testIcmpPing(host);
        } else {
          // VMess、VLESS、Trojan、Shadowsocks 等使用 TCP
          latency = await _testTcpConnectivity(host, port);
        }

        print('${latency >= 0 ? "✅" : "❌"} ${node.name}: ${latency >= 0 ? "${latency}ms" : "超时"}');
        return MapEntry(node.name, latency);
      } catch (e) {
        print('❌ [${node.name}] 测试出错: $e');
        return MapEntry(node.name, -1);
      }
    }).toList();

    // 等待所有测试完成（最多等待 3 秒）
    try {
      final entries = await Future.wait(futures).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⚠️ 测试超时，返回当前结果');
          return [];
        },
      );
      results.addEntries(entries);
    } catch (e) {
      print('❌ 批量测试出错: $e');
    }

    print('✅ 所有节点测试完成，共测试 ${results.length} 个节点');
    return results;
  }

  /// 快速 TCP 端口连通性测试
  /// 返回延迟毫秒数，失败返回 -1
  static Future<int> _testTcpConnectivity(String host, int port) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 1500), // 1.5 秒超时
      );
      
      stopwatch.stop();
      socket.destroy();
      
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return -1;
    }
  }

  /// ICMP Ping 测试（用于 Hysteria2）
  /// 返回延迟毫秒数，失败返回 -1
  static Future<int> _testIcmpPing(String host) async {
    try {
      final result = await Process.run(
        'ping',
        Platform.isWindows
            ? ['-n', '1', '-w', '1500', host]  // Windows: 1.5秒超时
            : ['-c', '1', '-W', '1', host],    // Linux/Android: 1秒超时
        runInShell: true,
      ).timeout(const Duration(seconds: 2));

      if (result.exitCode != 0) return -1;
      
      final output = (result.stdout ?? '').toString();

      if (Platform.isWindows) {
        // Windows: time=45ms 或 time<1ms 或 时间=45ms
        final m = RegExp(r'time[=<](\d+)ms|时间[=<](\d+)ms', caseSensitive: false)
            .firstMatch(output);
        if (m != null) {
          return int.tryParse(m.group(1) ?? m.group(2) ?? '0') ?? -1;
        }
      } else {
        // Linux/Android: time=45.2 ms
        final m = RegExp(r'time=(\d+\.?\d*)\s*ms').firstMatch(output);
        if (m != null) {
          return double.parse(m.group(1)!).round();
        }
      }
      
      return -1;
    } catch (e) {
      return -1;
    }
  }

  /// 从原始配置中提取端口号
  static int _extractPortFromRaw(String raw) {
    try {
      // VMess 协议特殊处理（Base64 编码）
      if (raw.startsWith('vmess://')) {
        try {
          final base64Part = raw.substring('vmess://'.length).split('#')[0];
          final decoded = utf8.decode(base64.decode(base64Part));
          final config = json.decode(decoded) as Map<String, dynamic>;
          final port = config['port'];
          if (port != null) {
            if (port is int) return port;
            if (port is String) return int.tryParse(port) ?? -1;
          }
        } catch (e) {
          print('❌ VMess 端口提取失败: $e');
        }
      }
      
      // 其他协议使用 URI 解析
      final uri = Uri.parse(raw);
      if (uri.port > 0) return uri.port;
      
      // 尝试从查询参数中提取
      final port = uri.queryParameters['port'];
      if (port != null) return int.tryParse(port) ?? -1;
      
      return -1;
    } catch (e) {
      print('❌ 端口提取失败: $e');
      return -1;
    }
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
      // VMess 协议特殊处理（Base64 编码）
      if (raw.startsWith('vmess://')) {
        try {
          final base64Part = raw.substring('vmess://'.length).split('#')[0];
          final decoded = utf8.decode(base64.decode(base64Part));
          final config = json.decode(decoded) as Map<String, dynamic>;
          final add = config['add'];
          if (add != null && add is String && add.isNotEmpty) {
            return add;
          }
        } catch (e) {
          print('❌ VMess 主机提取失败: $e');
        }
      }
      
      // 其他协议使用 URI 解析
      final uri = Uri.parse(raw);
      return uri.host;
    } catch (e) {
      print('❌ 主机提取失败: $e');
      return '';
    }
  }
}

