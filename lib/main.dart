import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/user_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '代理工具',
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

class _AuthWrapperState extends State<AuthWrapper> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // 初始化用户服务
    await _userService.init();
    
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
