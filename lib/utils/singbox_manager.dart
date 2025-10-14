import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/node_model.dart';
import 'node_config_converter.dart';

/// Sing-box 管理器
/// 负责 sing-box 进程的启动、停止和配置管理
class SingboxManager {
  static Process? _process;
  static String? _singboxPath;
  static String? _configPath;

  /// 获取 sing-box.exe 路径
  static String getSingboxPath() {
    if (_singboxPath != null) return _singboxPath!;

    // 开发环境：从项目根目录
    final devPath = path.join(Directory.current.path, 'sing-box.exe');
    if (File(devPath).existsSync()) {
      _singboxPath = devPath;
      return _singboxPath!;
    }

    // 发布环境：从 exe 同级目录
    final exeDir = path.dirname(Platform.resolvedExecutable);
    final bundlePath = path.join(exeDir, 'sing-box.exe');
    if (File(bundlePath).existsSync()) {
      _singboxPath = bundlePath;
      return _singboxPath!;
    }

    throw Exception('sing-box.exe 未找到！请确保已将其放置在正确位置。');
  }

  /// 获取配置文件路径
  static String getConfigPath() {
    if (_configPath != null) return _configPath!;

    final configDir = path.join(Directory.current.path, 'config');
    final dir = Directory(configDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    _configPath = path.join(configDir, 'sing-box-config.json');
    return _configPath!;
  }

  /// 生成 sing-box 配置文件（从节点对象）
  static Future<void> generateConfigFromNode({
    required NodeModel node,
    int mixedPort = 15808,
    bool enableTun = false,
  }) async {
    try {
      print('📝 正在为节点生成配置: ${node.displayName}');
      print('   协议: ${node.protocol}');
      
      // 使用转换器生成配置
      final config = NodeConfigConverter.generateFullConfig(
        node: node,
        mixedPort: mixedPort,
        enableTun: enableTun,
      );

      final configFile = File(getConfigPath());
      await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config),
      );

      print('✅ 配置文件已生成: ${configFile.path}');
    } catch (e) {
      print('❌ 生成配置失败: $e');
      rethrow;
    }
  }

  /// 生成 sing-box 配置文件（从节点URL - 已弃用，使用 generateConfigFromNode）
  @Deprecated('使用 generateConfigFromNode 代替')
  static Future<void> generateConfig({
    required String nodeUrl,
    String? nodeName,
    int mixedPort = 15808,
  }) async {
    // 尝试解析节点URL
    final node = NodeModel.fromSubscriptionLine(nodeUrl);
    if (node == null) {
      throw Exception('无法解析节点URL');
    }
    
    await generateConfigFromNode(node: node, mixedPort: mixedPort);
  }

  /// 启动 sing-box
  static Future<bool> start() async {
    try {
      // 检查是否已经运行
      if (_process != null) {
        print('⚠️ sing-box 已在运行中，先停止旧进程');
        await stop();
      }

      // 强制清理所有可能残留的 sing-box 进程
      await _killAllSingboxProcesses();

      final singboxPath = getSingboxPath();
      final configPath = getConfigPath();

      // 检查配置文件是否存在
      if (!File(configPath).existsSync()) {
        print('❌ 配置文件不存在，请先生成配置');
        return false;
      }

      print('🚀 启动 sing-box...');
      print('   路径: $singboxPath');
      print('   配置: $configPath');

      // 启动 sing-box 进程
      // Windows 下使用 normal 模式，可以监听输出
      _process = await Process.start(
        singboxPath,
        ['run', '-c', configPath],
        mode: ProcessStartMode.normal,
      );

      // 监听输出
      _process!.stdout.transform(utf8.decoder).listen((data) {
        print('[sing-box] $data');
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        print('[sing-box ERROR] $data');
      });

      // 监听进程退出
      _process!.exitCode.then((code) {
        print('sing-box 进程已退出，退出码: $code');
        _process = null;
      });

      // 等待一下确保进程启动
      await Future.delayed(const Duration(milliseconds: 500));

      print('✅ sing-box 启动成功');
      return true;
    } catch (e) {
      print('❌ 启动 sing-box 失败: $e');
      _process = null;
      return false;
    }
  }

  /// 停止 sing-box
  static Future<bool> stop() async {
    try {
      if (_process == null) {
        print('⚠️ sing-box 未运行');
        return false;
      }

      print('🛑 停止 sing-box...');
      
      // 杀死进程
      _process!.kill(ProcessSignal.sigterm);
      
      // 等待进程退出
      await _process!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // 如果超时，强制杀死
          _process!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      _process = null;
      print('✅ sing-box 已停止');
      return true;
    } catch (e) {
      print('❌ 停止 sing-box 失败: $e');
      _process = null;
      return false;
    }
  }

  /// 检查是否正在运行
  static bool isRunning() {
    return _process != null;
  }

  /// 重启 sing-box
  static Future<bool> restart() async {
    print('🔄 重启 sing-box...');
    await stop();
    await Future.delayed(const Duration(milliseconds: 500));
    return await start();
  }

  /// 清理所有残留的 sing-box 进程
  static Future<void> _killAllSingboxProcesses() async {
    try {
      if (Platform.isWindows) {
        // Windows: 使用 taskkill 强制终止所有 sing-box 进程
        final result = await Process.run(
          'taskkill',
          ['/F', '/IM', 'sing-box.exe'],
          runInShell: true,
        );
        
        if (result.exitCode == 0) {
          print('🧹 已清理残留的 sing-box 进程');
          
          // 等待进程完全终止，重试检查
          for (int i = 0; i < 10; i++) {
            await Future.delayed(const Duration(milliseconds: 200));
            
            // 检查进程是否还存在
            final checkResult = await Process.run(
              'tasklist',
              ['/FI', 'IMAGENAME eq sing-box.exe'],
              runInShell: true,
            );
            
            if (!checkResult.stdout.toString().contains('sing-box.exe')) {
              print('✅ sing-box 进程已完全终止');
              break;
            }
            
            if (i == 9) {
              print('⚠️ sing-box 进程可能仍在运行');
            }
          }
        }
        // 如果没有进程在运行，taskkill 会返回非0，这是正常的
      } else if (Platform.isLinux || Platform.isMacOS) {
        // Linux/macOS: 使用 pkill
        await Process.run('pkill', ['-9', 'sing-box']);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      // 忽略错误，可能是没有进程在运行
      print('🔍 检查进程: $e');
    }
  }
}

