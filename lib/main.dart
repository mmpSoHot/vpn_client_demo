import 'package:flutter/material.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/user_service.dart';
import 'services/config_service.dart';
import 'utils/system_proxy_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 应用启动时清理残留资源
  await _cleanupOnAppStart();
  
  // 如果是桌面平台，设置窗口大小
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    
    const windowOptions = WindowOptions(
      size: Size(400, 780),        // 窗口大小：宽400，高780
      minimumSize: Size(380, 700), // 最小尺寸
      maximumSize: Size(480, 900), // 最大尺寸
      center: true,                // 居中显示
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: '代理工具',
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  runApp(const MyApp());
}

/// 应用启动时清理残留资源
Future<void> _cleanupOnAppStart() async {
  try {
    print('🧹 应用启动，检查并清理残留资源...');
    
    // 清理残留的 sing-box 进程
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/F', '/IM', 'sing-box.exe'], runInShell: true);
    } else if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('pkill', ['-9', 'sing-box']);
    }
    
    // 清除系统代理（如果之前异常退出留下的）
    await SystemProxyHelper.clearProxy();
    
    print('✅ 资源清理完成');
  } catch (e) {
    // 忽略错误，可能是没有残留进程
    print('🔍 清理检查: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '代理工具',
      debugShowCheckedModeBanner: false, // 去掉右上角的 debug 标记
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF)),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WindowListener {
  final UserService _userService = UserService();
  final ConfigService _configService = ConfigService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    
    // 添加窗口关闭监听
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    // 移除窗口监听
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // 窗口关闭时清理资源
    print('🪟 窗口即将关闭，清理资源...');
    
    try {
      // 清理 sing-box 进程
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/IM', 'sing-box.exe'], runInShell: true);
      } else if (Platform.isLinux || Platform.isMacOS) {
        await Process.run('pkill', ['-9', 'sing-box']);
      }
      
      // 清除系统代理
      await SystemProxyHelper.clearProxy();
      
      print('✅ 资源清理完成，窗口关闭');
    } catch (e) {
      print('⚠️ 清理时出错: $e');
    }
    
    // 允许窗口关闭
    await windowManager.destroy();
  }

  Future<void> _checkAuthStatus() async {
    // 并行初始化用户服务和配置服务
    await Future.wait([
      _userService.init(),
      _configService.init(),
    ]);
    
    // 检查登录状态
    final isLoggedIn = _userService.isLoggedIn;
    
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
              ),
              SizedBox(height: 16),
              Text(
                '正在加载...',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 根据登录状态显示不同页面
    return _isLoggedIn ? const HomePage() : const LoginPage();
  }
}
