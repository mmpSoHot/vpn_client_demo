import 'package:flutter/material.dart';
import 'register_page.dart';
import 'home_page.dart';
import '../services/user_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberPassword = false;
  bool _isLoading = false;

  // 创建用户服务实例
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 加载保存的登录凭据
  Future<void> _loadSavedCredentials() async {
    final credentials = await _userService.getSavedCredentials();
    final remember = await _userService.isRememberPassword();
    
    if (mounted) {
      setState(() {
        _rememberPassword = remember;
        if (remember && credentials['username'] != null) {
          _usernameController.text = credentials['username']!;
          _passwordController.text = credentials['password'] ?? '';
        }
      });
    }
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await _userService.login(
          _usernameController.text.trim(),
          _passwordController.text,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (result['success']) {
            // 保存记住密码设置和凭据
            await _userService.setRememberPassword(_rememberPassword);
            if (_rememberPassword) {
              await _userService.saveCredentials(
                _usernameController.text.trim(),
                _passwordController.text,
              );
            } else {
              await _userService.saveCredentials('', '');
            }

            // 登录成功
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: const Color(0xFF4CAF50),
              ),
            );
            
            // 跳转到首页
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else {
            // 登录失败
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: const Color(0xFFF44336),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录失败，请稍后重试'),
              backgroundColor: Color(0xFFF44336),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                
                // 标题
                const Text(
                  '欢迎回来',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请登录您的账户',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 40),
                
                // 用户名输入框
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: '用户名',
                    hintText: '请输入用户名',
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF999999)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入用户名';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // 密码输入框
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '请输入密码',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF999999)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xFF999999),
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    if (value.length < 6) {
                      return '密码至少6位';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // 记住密码选项
                Row(
                  children: [
                    Checkbox(
                      value: _rememberPassword,
                      onChanged: (value) {
                        setState(() {
                          _rememberPassword = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFF007AFF),
                    ),
                    const Text(
                      '记住密码',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // 忘记密码功能
                        _showForgotPasswordDialog();
                      },
                      child: const Text(
                        '忘记密码？',
                        style: TextStyle(
                          color: Color(0xFF007AFF),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                
                // 登录按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '登录',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // 注册链接
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '还没有账户？',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                      child: const Text(
                        '立即注册',
                        style: TextStyle(
                          color: Color(0xFF007AFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // 测试账号提示
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2196F3), width: 1),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '测试账号：',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '用户名：admin / user / test\n密码：123456',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('忘记密码'),
        content: const Text('请联系客服重置密码\n客服电话：400-123-4567'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
} 