import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../utils/http_client.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailUsernameController = TextEditingController(); // 邮箱用户名部分
  final _emailCodeController = TextEditingController(); // 邮箱验证码
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController(); // 邀请码
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String _selectedEmailSuffix = 'gmail.com'; // 选中的邮箱后缀

  // 创建服务实例
  final ConfigService _configService = ConfigService();
  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();
  final HttpClient _httpClient = HttpClient();
  
  // 验证码倒计时
  int _countdown = 0;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    // 设置默认邮箱后缀
    final suffixes = _configService.getEmailSuffixOptions();
    if (suffixes.isNotEmpty) {
      _selectedEmailSuffix = suffixes.first;
    }
  }

  @override
  void dispose() {
    _emailUsernameController.dispose();
    _emailCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    _timer?.cancel();
    super.dispose();
  }
  
  // 开始倒计时
  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // 发送邮箱验证码
  void _sendEmailCode() async {
    // 如果正在倒计时，不允许重复发送
    if (_countdown > 0) {
      return;
    }
    
    // 验证邮箱用户名是否填写
    if (_emailUsernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入邮箱'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
      return;
    }
    
    // 拼接完整邮箱
    final email = '${_emailUsernameController.text.trim()}@$_selectedEmailSuffix';
    
    // 验证邮箱后缀
    if (!_configService.isEmailSuffixAllowed(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该邮箱后缀不支持注册'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
      return;
    }
    
    try {
      // 调用发送邮箱验证码API
      final response = await _apiService.sendEmailVerify(email);
      
      if (response.success) {
        // 发送成功，开始倒计时
        _startCountdown();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? '验证码已发送到 $email'),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      } else {
        // 发送失败
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? '发送失败，请稍后重试'),
              backgroundColor: const Color(0xFFF44336),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('网络错误，请稍后重试'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
      }
    }
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      // 拼接完整邮箱
      final email = '${_emailUsernameController.text.trim()}@$_selectedEmailSuffix';
      
      // 验证邮箱后缀是否在白名单中
      if (!_configService.isEmailSuffixAllowed(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('该邮箱后缀不支持注册'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
        return;
      }
      
      // 如果开启了邮箱验证，检查验证码
      if (_configService.isEmailVerify && _emailCodeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请输入邮箱验证码'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // 调用真实的注册API
        final response = await _apiService.register(
          email: email,
          password: _passwordController.text,
          emailCode: _configService.isEmailVerify ? _emailCodeController.text.trim() : null,
          inviteCode: _inviteCodeController.text.trim().isNotEmpty ? _inviteCodeController.text.trim() : null,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (response.success) {
            // 注册成功，解析响应数据
            final authData = response.data['auth_data']; // 格式: "Bearer xxx"
            final isAdmin = response.data['is_admin'];
            
            // auth_data已经包含Bearer前缀，提取token
            if (authData != null && authData.toString().startsWith('Bearer ')) {
              final token = authData.toString().substring(7); // 去掉"Bearer "
              await _httpClient.setToken(token);
              
              // 同时保存完整的auth_data
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('auth_data', authData);
            }
            
            // 设置用户登录状态
            await _userService.setUserFromApi(
              email,
              isVip: false,
              isAdmin: isAdmin ?? false,
            );
            
            // 显示注册成功提示
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.message ?? '注册成功！'),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 1),
              ),
            );
            
            // 延迟一下再跳转，让用户看到提示
            await Future.delayed(const Duration(milliseconds: 500));
            
            // 注册成功后直接跳转到首页
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false, // 清除所有路由栈
              );
            }
          } else {
            // 注册失败
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.message ?? '注册失败'),
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
            SnackBar(
              content: Text('网络错误：${e.toString()}'),
              backgroundColor: const Color(0xFFF44336),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '注册账户',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // 标题
                const Text(
                  '创建新账户',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请填写以下信息完成注册',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 30),
                
                // 邮箱输入框 - 用户名 + @ + 后缀选择
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '邮箱',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // 邮箱用户名输入框
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _emailUsernameController,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              hintText: '',
                              hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF999999)),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入邮箱用户名';
                              }
                              if (value.contains('@') || value.contains(' ')) {
                                return '只需输入@前面的部分';
                              }
                              return null;
                            },
                          ),
                        ),
                        // @ 符号
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '@',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        // 邮箱后缀下拉选择
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedEmailSuffix,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF999999)),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF333333),
                                ),
                                items: _configService.getEmailSuffixOptions().map((suffix) {
                                  return DropdownMenuItem(
                                    value: suffix,
                                    child: Text(suffix),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedEmailSuffix = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                
                // 确认密码输入框
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: '确认密码',
                    hintText: '请再次输入密码',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF999999)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xFF999999),
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
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
                      return '请确认密码';
                    }
                    if (value != _passwordController.text) {
                      return '两次输入的密码不一致';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // 邮箱验证码输入框（根据配置显示）
                if (_configService.isEmailVerify) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _emailCodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '邮箱验证码',
                            hintText: '请输入验证码',
                            prefixIcon: const Icon(Icons.verified_outlined, color: Color(0xFF999999)),
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
                            if (_configService.isEmailVerify && (value == null || value.isEmpty)) {
                              return '请输入邮箱验证码';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 发送验证码按钮
                      SizedBox(
                        width: 120,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _countdown > 0 ? null : _sendEmailCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE0E0E0),
                            disabledForegroundColor: const Color(0xFF999999),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _countdown > 0 ? '$_countdown秒' : '发送验证码',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                
                // 邀请码输入框（选填）
                TextFormField(
                  controller: _inviteCodeController,
                  decoration: InputDecoration(
                    labelText: '邀请码（选填）',
                    hintText: _configService.isInviteForce ? '请输入邀请码（必填）' : '有邀请码可填写',
                    prefixIcon: const Icon(Icons.card_giftcard_outlined, color: Color(0xFF999999)),
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
                    // 如果强制邀请，则必填
                    if (_configService.isInviteForce && (value == null || value.isEmpty)) {
                      return '请输入邀请码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
            
                
                // 注册按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
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
                            '注册',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // 返回登录
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '已有账号？',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        '立即登录',
                        style: TextStyle(
                          color: Color(0xFF007AFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 