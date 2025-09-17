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
          isProxyEnabled: _isProxyEnabled,
          onConnectionStateChanged: (bool newState) {
            setState(() {
              _isProxyEnabled = newState;
            });
          },
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
                        color: widget.isProxyEnabled ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
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
          
          // 连接按钮 - 超精美圆形设计（快速动画版）
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 多层光晕效果
                ...List.generate(3, (index) {
                  return IgnorePointer(
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200 + (index * 50)), // 大幅加快
                      width: widget.isProxyEnabled ? 160 - (index * 15) : 140 - (index * 10),
                      height: widget.isProxyEnabled ? 160 - (index * 15) : 140 - (index * 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (widget.isProxyEnabled 
                            ? [const Color(0xFFF44336), const Color(0xFFE57373), const Color(0xFFFFCDD2)]
                            : [const Color(0xFF4CAF50), const Color(0xFF81C784), const Color(0xFFC8E6C9)])[index]
                            .withOpacity(0.1 - (index * 0.02)),
                      ),
                    ),
                  );
                }),
                
                // 主按钮容器
                GestureDetector(
                  onTap: () {
                _handleConnectionButton();
              },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150), // 大幅加快
                    curve: Curves.easeInOut, // 改为更快的曲线
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.3),
                        radius: 1.2,
                        colors: widget.isProxyEnabled 
                            ? [
                                const Color(0xFFFF6B6B),
                                const Color(0xFFF44336),
                                const Color(0xFFD32F2F),
                                const Color(0xFFB71C1C),
                              ]
                            : [
                                const Color(0xFF66BB6A),
                                const Color(0xFF4CAF50),
                                const Color(0xFF388E3C),
                                const Color(0xFF2E7D32),
                              ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                      boxShadow: [
                        // 主阴影
                        BoxShadow(
                          color: (widget.isProxyEnabled ? const Color(0xFFF44336) : const Color(0xFF4CAF50)).withOpacity(0.6),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 2,
                        ),
                        // 内阴影效果
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        // 高光效果
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(-3, -3),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 3,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // 背景纹理
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(0.2, 0.2),
                                  radius: 0.8,
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 主要内容
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 图标容器
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200), // 大幅加快
                                    transitionBuilder: (Widget child, Animation<double> animation) {
                                      return RotationTransition(
                                        turns: animation,
                                        child: ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      widget.isProxyEnabled ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded,
                                      key: ValueKey(widget.isProxyEnabled),
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // 文字
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 150), // 大幅加快
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        offset: const Offset(0, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
              ),
              child: Text(
                                    widget.isProxyEnabled ? '断开' : '连接',
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
                
                // 连接状态指示器 - 更精美
                if (widget.isProxyEnabled)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 200), // 大幅加快
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                              ),
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4CAF50).withOpacity(0.6),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                
                // 脉冲动画效果
                if (widget.isProxyEnabled)
                  IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800), // 加快脉冲速度
                      tween: Tween(begin: 0.8, end: 1.2),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
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
                              builder: (context) => NodeSelectionPage(
                                selectedNode: widget.selectedNode,
                                onNodeSelected: widget.onNodeChanged,
                              ),
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
        backgroundColor: newState ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
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
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final List<_UsageRecord> _items = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isRefreshing = true;
      _hasMore = true;
      _page = 1;
    });
    final data = await _fetchPage(_page, _pageSize);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(data);
      _hasMore = data.length == _pageSize;
      _isRefreshing = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _page += 1;
    });
    final data = await _fetchPage(_page, _pageSize);
    if (!mounted) return;
    setState(() {
      _items.addAll(data);
      _hasMore = data.length == _pageSize;
      _isLoading = false;
    });
  }

  // 模拟分页接口
  Future<List<_UsageRecord>> _fetchPage(int page, int pageSize) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final List<_UsageRecord> result = [];
    final DateTime today = DateTime.now();
    final int start = (page - 1) * pageSize;
    for (int i = 0; i < pageSize; i++) {
      final day = today.subtract(Duration(days: start + i));
      // 构造一些看起来合理的数据
      final double upMB = 5 + (start + i) * 0.3; // 例如 7.95 MB
      final double downMB = 600 + ((start + i) * 4.2); // 例如 804.36 MB
      final double ratio = 0.8; // 扣费倍率 0.80x
      result.add(_UsageRecord(date: day, uploadMB: upMB, downloadMB: downMB, ratio: ratio));
    }
    return result;
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatMB(double mb) {
    return '${mb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            if (_isRefreshing) {
              return const SizedBox.shrink();
            }
            if (_isLoading) {
              return _buildLoadingFooter();
            }
            if (!_hasMore) {
              return _buildNoMoreFooter();
            }
            return const SizedBox.shrink();
          }
          final item = _items[index];
          final String dateStr = _formatDate(item.date);
          final double totalMB = (item.uploadMB + item.downloadMB) * item.ratio;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '记录时间',
                      style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetric(label: '实际上行', value: _formatMB(item.uploadMB), color: const Color(0xFF007AFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetric(label: '实际下行', value: _formatMB(item.downloadMB), color: const Color(0xFF4CAF50)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetric(label: '扣费倍率', value: '${item.ratio.toStringAsFixed(2)} x', color: const Color(0xFFFF9800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetric(label: '总计', value: _formatMB(totalMB), color: const Color(0xFF9C27B0)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetric({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('加载中...')
        ],
      ),
    );
  }

  Widget _buildNoMoreFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
      child: Text(
          '没有更多了',
          style: TextStyle(color: Color(0xFF999999)),
        ),
      ),
    );
  }
}

class _UsageRecord {
  final DateTime date;
  final double uploadMB;
  final double downloadMB;
  final double ratio;

  _UsageRecord({required this.date, required this.uploadMB, required this.downloadMB, required this.ratio});
} 