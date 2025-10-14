import 'package:flutter/material.dart';
import 'proxy_mode_page.dart';
import 'node_selection_page.dart';
import 'vip_recharge_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import '../services/user_service.dart';
import '../services/api_service.dart';
import '../models/subscribe_model.dart';
import '../utils/auth_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedNode = '自动选择';
  int _currentIndex = 0;
  bool _isProxyEnabled = false;
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_membership),
            label: '套餐',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
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
          isProxyEnabled: _isProxyEnabled,
          onConnectionStateChanged: (bool newState) {
            setState(() {
              _isProxyEnabled = newState;
            });
          },
        );
      case 1:
        return const VipRechargePage();
      case 2:
        return const ProfilePage();
      default:
        return HomeContent(
          selectedNode: _selectedNode,
          onNodeChanged: _updateSelectedNode,
          isProxyEnabled: _isProxyEnabled,
          onConnectionStateChanged: (bool newState) {
            setState(() {
              _isProxyEnabled = newState;
            });
          },
        );
    }
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return '首页';
      case 1:
        return 'VIP套餐';
      case 2:
        return '我的';
      default:
        return '首页';
    }
  }
}

// 首页内容组件
class HomeContent extends StatefulWidget {
  final String selectedNode;
  final Function(String) onNodeChanged;
  final bool isProxyEnabled;
  final Function(bool) onConnectionStateChanged;

  const HomeContent({
    super.key,
    this.selectedNode = '自动选择',
    required this.onNodeChanged,
    this.isProxyEnabled = false,
    required this.onConnectionStateChanged,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  String _connectionStatus = '未连接';
  final UserService _userService = UserService();
  final ApiService _apiService = ApiService();
  SubscribeModel? _subscribeInfo;
  bool _isLoadingSubscribe = false;

  @override
  void initState() {
    super.initState();
    // 监听用户服务状态变化
    _userService.addListener(_onUserServiceChanged);
    // 如果已登录，加载订阅信息
    if (_userService.isLoggedIn) {
      _loadSubscribeInfo();
    }
  }

  /// 加载订阅信息
  Future<void> _loadSubscribeInfo() async {
    setState(() {
      _isLoadingSubscribe = true;
    });

    try {
      final response = await _apiService.getSubscribe();

      // 检查是否未授权
      if (mounted && !await AuthHelper.checkAndHandleAuth(context, response)) {
        return;
      }

      if (response.success && response.data != null) {
        if (mounted) {
          setState(() {
            _subscribeInfo = SubscribeModel.fromJson(response.data);
            _isLoadingSubscribe = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingSubscribe = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSubscribe = false;
        });
      }
    }
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
    return Stack(
      children: [
        // 主要内容区域
        SingleChildScrollView(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isProxyEnabled
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFF44336),
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
                                builder: (context) => NodeSelectionPage(
                                  selectedNode: widget.selectedNode,
                                  onNodeSelected: widget.onNodeChanged,
                                ),
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

              // 订阅信息卡片
              if (_userService.isLoggedIn && _subscribeInfo != null)
                _buildSubscriptionCard(),

              if (_userService.isLoggedIn && _subscribeInfo != null)
                const SizedBox(height: 10),

              // 功能按钮区域
              Column(
                children: [
                  // 第一行按钮
                ],
              ),
              const SizedBox(height: 80), // 底部留空给悬浮按钮
            ],
          ),
        ),

        // 悬浮连接按钮 - 精美设计
        Positioned(
          right: 10,
          bottom: 0,
          child: GestureDetector(
            onTap: _handleConnectionButton,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 外层光晕
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: widget.isProxyEnabled ? 90 : 80,
                  height: widget.isProxyEnabled ? 90 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        (widget.isProxyEnabled
                                ? const Color(0xFFF44336)
                                : const Color(0xFF4CAF50))
                            .withOpacity(0.15),
                  ),
                ),
                // 主按钮
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.3),
                      radius: 1.0,
                      colors: widget.isProxyEnabled
                          ? [
                              const Color(0xFFFF6B6B),
                              const Color(0xFFF44336),
                              const Color(0xFFD32F2F),
                            ]
                          : [
                              const Color(0xFF66BB6A),
                              const Color(0xFF4CAF50),
                              const Color(0xFF388E3C),
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (widget.isProxyEnabled
                                    ? const Color(0xFFF44336)
                                    : const Color(0xFF4CAF50))
                                .withOpacity(0.6),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        widget.isProxyEnabled
                            ? Icons.power_settings_new_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(widget.isProxyEnabled),
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                // 连接状态小圆点
                if (widget.isProxyEnabled)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4CAF50),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建订阅信息卡片
  Widget _buildSubscriptionCard() {
    if (_subscribeInfo == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _subscribeInfo!.hasSubscription
            ? const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 套餐名称
          Row(
            children: [
              Icon(
                Icons.star,
                color: _subscribeInfo!.hasSubscription
                    ? Colors.white
                    : const Color(0xFF666666),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _subscribeInfo!.planName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _subscribeInfo!.hasSubscription
                        ? Colors.white
                        : const Color(0xFF666666),
                  ),
                ),
              ),
            ],
          ),

          if (_subscribeInfo!.hasSubscription) ...[
            const SizedBox(height: 12),

            // 流量使用进度
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已用: ${_subscribeInfo!.usedTrafficFormatted}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      '总计: ${_subscribeInfo!.totalTrafficFormatted}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _subscribeInfo!.usagePercentage / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _subscribeInfo!.usagePercentage > 80
                          ? const Color(0xFFF44336)
                          : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_subscribeInfo!.usagePercentage.toStringAsFixed(1)}% 已使用',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 到期时间和重置时间
            Text(
              _subscribeInfo!.expireInfo,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            if (_subscribeInfo!.resetInfo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _subscribeInfo!.resetInfo,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              '您还未购买订阅，请先购买VIP套餐',
              style: TextStyle(color: Color(0xFF666666), fontSize: 12),
            ),
          ],
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
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    // 已登录，切换连接状态
    final newState = !widget.isProxyEnabled;

    setState(() {
      _connectionStatus = newState ? '已连接' : '未连接';
    });

    // 通知父组件状态变化
    widget.onConnectionStateChanged(newState);

    // 显示连接状态提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newState ? '连接成功' : '已断开连接'),
        backgroundColor: newState
            ? const Color(0xFF4CAF50)
            : const Color(0xFFF44336),
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
            Icon(icon, color: color, size: 24),
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
