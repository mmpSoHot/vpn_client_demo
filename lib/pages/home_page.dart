import 'package:flutter/material.dart';
import 'proxy_mode_page.dart';
import 'node_selection_page.dart';
import 'vip_recharge_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import '../services/user_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isProxyEnabled = false;
  String _selectedNode = '自动选择';
  String _connectionStatus = '未连接';
  int _currentIndex = 0;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
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
    // 当用户服务状态改变时，刷新页面
    if (mounted) {
      setState(() {});
    }
  }

  void _updateSelectedNode(String nodeName) {
    if (mounted) {
      setState(() {
        _selectedNode = nodeName;
      });
      
      // 显示选择成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已选择节点：$nodeName'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // 延迟一下再切换到首页，让用户看到提示
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _currentIndex = 0; // 切换到首页
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _getTitle(),
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFF333333)),
              onPressed: () {
                // 设置页面
              },
            ),
        ],
      ),
      body: _getCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF007AFF),
        unselectedItemColor: const Color(0xFF999999),
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: '节点',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: '统计',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return HomeContent(
          selectedNode: _selectedNode,
          onNodeChanged: _updateSelectedNode,
        );
      case 1:
        return NodeSelectionPage(
          selectedNode: _selectedNode,
          onNodeSelected: _updateSelectedNode,
        );
      case 2:
        return const StatisticsPage();
      case 3:
        return const ProfilePage();
      default:
        return HomeContent(
          selectedNode: _selectedNode,
          onNodeChanged: _updateSelectedNode,
        );
    }
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return '代理工具';
      case 1:
        return '节点选择';
      case 2:
        return '使用统计';
      case 3:
        return '我的';
      default:
        return '代理工具';
    }
  }
}

// 首页内容组件
class HomeContent extends StatefulWidget {
  final String selectedNode;
  final Function(String) onNodeChanged;

  const HomeContent({
    super.key,
    this.selectedNode = '自动选择',
    required this.onNodeChanged,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _isProxyEnabled = false;
  String _connectionStatus = '未连接';
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
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
    // 当用户服务状态改变时，刷新页面
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 状态卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: Column(
              children: [
                // 连接状态
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '连接状态',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isProxyEnabled ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _connectionStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 当前节点
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '当前节点',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NodeSelectionPage(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            widget.selectedNode,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Color(0xFF007AFF),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 连接按钮
          Container(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                _handleConnectionButton();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isProxyEnabled ? const Color(0xFFF44336) : const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                _isProxyEnabled ? '断开连接' : '连接',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 功能按钮
          Expanded(
            child: Column(
              children: [
                // 第一行按钮
                Row(
                  children: [
                    Expanded(
                      child: _buildFeatureButton(
                        icon: Icons.vpn_key,
                        title: '代理模式',
                        color: const Color(0xFF007AFF),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProxyModePage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFeatureButton(
                        icon: Icons.location_on,
                        title: '节点选择',
                        color: const Color(0xFF4CAF50),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NodeSelectionPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // 第二行按钮
                Row(
                  children: [
                    Expanded(
                      child: _buildFeatureButton(
                        icon: Icons.star,
                        title: 'VIP充值',
                        color: const Color(0xFFFF9800),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VipRechargePage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFeatureButton(
                        icon: Icons.analytics,
                        title: '使用统计',
                        color: const Color(0xFF9C27B0),
                        onTap: () {
                          // 使用统计页面
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleConnectionButton() {
    // 检查是否已登录
    if (!_userService.isLoggedIn) {
      // 未登录，跳转到登录页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      return;
    }

    // 已登录，切换连接状态
    setState(() {
      _isProxyEnabled = !_isProxyEnabled;
      _connectionStatus = _isProxyEnabled ? '已连接' : '未连接';
    });

    // 显示连接状态提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isProxyEnabled ? '连接成功' : '已断开连接'),
        backgroundColor: _isProxyEnabled ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 统计页面组件
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '使用统计页面',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
} 