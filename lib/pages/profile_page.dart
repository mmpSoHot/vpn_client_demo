import 'package:flutter/material.dart';
import 'login_page.dart';
import '../services/user_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  bool _isLoggedIn = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    // 监听用户服务状态变化
    _userService.addListener(_onUserServiceChanged);
  }

  @override
  void dispose() {
    // 移除监听器
    _userService.removeListener(_onUserServiceChanged);
    super.dispose();
  }

  void _onUserServiceChanged() {
    // 当用户服务状态改变时，刷新用户信息
    _loadUserInfo();
  }

  void _loadUserInfo() {
    _isLoggedIn = _userService.isLoggedIn;
    _currentUser = _userService.currentUser;
    setState(() {});
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认登出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 执行登出操作
      await _userService.logout();
      
      if (mounted) {
        // 刷新页面状态
        _loadUserInfo();
        
        // 显示登出成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已退出登录'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // 用户信息头部区域
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoggedIn ? _buildLoggedInUserInfo() : _buildNotLoggedInUserInfo(),
          ),
          
          // 功能列表
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // 会员信息卡片
                  if (_isLoggedIn && _currentUser != null) ...[
                    _buildMemberCard(),
                    const SizedBox(height: 16),
                  ],
                  
                  // 功能列表
                  _buildFunctionList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedInUserInfo() {
    return Row(
      children: [
        // 默认头像
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(
            Icons.person,
            size: 30,
            color: Color(0xFF999999),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '未登录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '点击登录享受更多服务',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginPage(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            '登录',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedInUserInfo() {
    return Column(
      children: [
        // 用户基本信息行
        Row(
          children: [
            // 用户头像
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _currentUser?.isVip == true 
                    ? const Color(0xFFFFD700) 
                    : const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                _currentUser?.isVip == true ? Icons.star : Icons.person,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUser?.username ?? '用户名',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser?.email ?? 'user@example.com',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // 编辑用户信息
              },
              icon: const Icon(
                Icons.edit,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 用户状态信息
        Row(
          children: [
            // VIP状态
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: _currentUser?.isVip == true 
                      ? const Color(0xFFFFD700).withOpacity(0.1)
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentUser?.isVip == true ? Icons.star : Icons.person,
                      size: 16,
                      color: _currentUser?.isVip == true 
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF666666),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentUser?.isVip == true ? 'VIP会员' : '普通用户',
                      style: TextStyle(
                        fontSize: 12,
                        color: _currentUser?.isVip == true 
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // 登出按钮
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF44336).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTap: _logout,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout,
                      size: 16,
                      color: Color(0xFFF44336),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '登出',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF44336),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberCard() {
    if (_currentUser?.isVip == true) {
      // VIP用户显示会员信息
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.star,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VIP会员',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '到期时间：${_currentUser?.vipExpireDate?.toString().substring(0, 10) ?? '永久'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '已激活',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 普通用户显示升级提示
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.star,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '升级VIP会员',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '享受无限流量、专属节点等特权',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // 跳转到VIP充值页面
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFFA000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                '立即升级',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFunctionList() {
    final List<Map<String, dynamic>> functions = [
      {
        'icon': Icons.history,
        'title': '使用记录',
        'subtitle': '查看历史使用情况',
        'onTap': () {},
      },
      {
        'icon': Icons.help_outline,
        'title': '帮助中心',
        'subtitle': '常见问题解答',
        'onTap': () {},
      },
      {
        'icon': Icons.feedback,
        'title': '意见反馈',
        'subtitle': '告诉我们您的建议',
        'onTap': () {},
      },
      {
        'icon': Icons.info_outline,
        'title': '关于我们',
        'subtitle': '版本信息及联系方式',
        'onTap': () {},
      },
    ];

    return Expanded(
      child: ListView.builder(
        itemCount: functions.length,
        itemBuilder: (context, index) {
          final function = functions[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  function['icon'],
                  color: const Color(0xFF007AFF),
                  size: 20,
                ),
              ),
              title: Text(
                function['title'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
              subtitle: Text(
                function['subtitle'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF999999),
              ),
              onTap: function['onTap'],
            ),
          );
        },
      ),
    );
  }
} 