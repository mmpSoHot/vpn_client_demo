import 'dart:async';
import 'package:flutter/material.dart';
import 'node_selection_page.dart';
import 'vip_recharge_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'singbox_test_page.dart';
import '../services/user_service.dart';
import '../services/api_service.dart';
import '../models/subscribe_model.dart';
import '../models/node_model.dart';
import '../utils/auth_helper.dart';
import '../utils/singbox_manager.dart';
import '../utils/system_proxy_helper.dart';

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
    
    // 应用关闭时清理资源
    _cleanupOnAppClose();
    
    super.dispose();
  }

  /// 应用关闭时清理资源
  Future<void> _cleanupOnAppClose() async {
    try {
      // 如果 VPN 正在连接，清理资源
      if (_isProxyEnabled) {
        print('🧹 应用关闭，清理 VPN 资源...');
        
        // 清除系统代理
        await SystemProxyHelper.clearProxy();
        
        // 停止 sing-box
        await SingboxManager.stop();
        
        print('✅ 资源清理完成');
      }
    } catch (e) {
      print('⚠️ 清理资源时出错: $e');
    }
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
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.bug_report, color: Color(0xFF007AFF)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SingboxTestPage()),
                );
              },
              tooltip: 'Sing-box 测试',
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFF333333)),
              onPressed: () {
                // 设置页面
              },
            ),
          ],
        ],
      ),
      body: _getCurrentPage(),
      // 添加 FloatingActionButton
      floatingActionButton: _currentIndex == 0 ? _buildVPNFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

  // 保存 HomeContent 的 key 以便调用其方法
  final GlobalKey<_HomeContentState> _homeContentKey = GlobalKey();

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return HomeContent(
          key: _homeContentKey,
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
          key: _homeContentKey,
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

  /// 构建 VPN 开关 FloatingActionButton
  Widget _buildVPNFAB() {
    final homeContentState = _homeContentKey.currentState;
    final isConnecting = homeContentState?._isConnecting ?? false;
    
    // 确定按钮颜色和图标
    Color backgroundColor;
    Widget icon;
    String label;
    String tooltip;

    if (isConnecting) {
      // 连接中 - 蓝色
      backgroundColor = const Color(0xFF2196F3);
      icon = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      );
      label = '连接中...';
      tooltip = '正在连接';
    } else if (_isProxyEnabled) {
      // 已连接 - 红色
      backgroundColor = const Color(0xFFF44336);
      icon = const Icon(Icons.power_settings_new_rounded, color: Colors.white);
      label = '断开';
      tooltip = '断开 VPN';
    } else {
      // 未连接 - 绿色
      backgroundColor = const Color(0xFF4CAF50);
      icon = const Icon(Icons.play_arrow_rounded, color: Colors.white);
      label = '连接';
      tooltip = '连接 VPN';
    }

    return FloatingActionButton.extended(
      onPressed: isConnecting ? null : () {
        // 调用 HomeContent 中的连接方法
        _homeContentKey.currentState?._handleConnectionButton();
      },
      backgroundColor: backgroundColor,
      icon: icon,
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      tooltip: tooltip,
      elevation: 6,
      highlightElevation: 12,
    );
  }
}

// 首页内容组件
class HomeContent extends StatefulWidget {
  final String selectedNode;
  final Function(String) onNodeChanged;
  final bool isProxyEnabled;
  final Function(bool) onConnectionStateChanged;
  final VoidCallback? onConnectionButtonPressed; // 新增回调

  const HomeContent({
    super.key,
    this.selectedNode = '自动选择',
    required this.onNodeChanged,
    this.isProxyEnabled = false,
    required this.onConnectionStateChanged,
    this.onConnectionButtonPressed, // 新增参数
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
  bool _isConnecting = false; // 连接中的状态
  Timer? _statusChecker; // 状态检查定时器
  NodeModel? _selectedNodeModel; // 当前选中的节点对象

  @override
  void initState() {
    super.initState();
    // 监听用户服务状态变化
    _userService.addListener(_onUserServiceChanged);
    // 如果已登录，加载订阅信息
    if (_userService.isLoggedIn) {
      _loadSubscribeInfo();
    }
    // 启动状态监控
    _startStatusChecker();
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
    // 停止状态检查
    _statusChecker?.cancel();
    super.dispose();
  }

  void _onUserServiceChanged() {
    // 当用户服务状态改变时，刷新页面
    if (mounted) {
      setState(() {});
    }
  }

  /// 启动状态监控
  void _startStatusChecker() {
    _statusChecker = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) return;
      
      // 如果正在连接中，跳过状态检查
      if (_isConnecting) return;

      // 检查 sing-box 是否运行
      bool singboxRunning = SingboxManager.isRunning();

      // 检查系统代理是否设置
      bool proxySet = await SystemProxyHelper.isProxySetTo('127.0.0.1', 15808);

      // 更新连接状态
      bool isConnected = singboxRunning && proxySet;

      if (mounted && widget.isProxyEnabled != isConnected) {
        // 如果 sing-box 意外停止，清除系统代理
        if (!singboxRunning && proxySet) {
          print('⚠️ 检测到 sing-box 异常停止，清除系统代理');
          await SystemProxyHelper.clearProxy();
        }

        // 更新状态
        setState(() {
          _connectionStatus = isConnected ? '已连接' : '未连接';
        });
        widget.onConnectionStateChanged(isConnected);
        
        // 显示提示
        if (!isConnected && widget.isProxyEnabled) {
          _showError('VPN 连接已断开');
        }
      }
    });
  }

  /// 连接 VPN
  Future<void> _connectVPN() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = '连接中...';
    });
    // 通知父组件刷新 FAB
    widget.onConnectionStateChanged(widget.isProxyEnabled);

    try {
      // Step 1: 获取节点（这里使用示例节点，实际应从服务器获取）
      if (_selectedNodeModel == null) {
        // TODO: 从订阅URL获取节点列表
        // 现在使用一个示例节点
        final subscribe = _subscribeInfo;
        if (subscribe == null) {
          if (mounted) {
            _showError('获取订阅信息失败');
            setState(() {
              _isConnecting = false;
              _connectionStatus = '未连接';
            });
          }
          return;
        }

        // 使用示例节点（后续需要实现真实的节点获取逻辑）
        _selectedNodeModel = NodeModel(
          name: widget.selectedNode,
          protocol: 'Hysteria2',
          location: '香港',
          rawConfig:
              'hysteria2://${subscribe.uuid}@example.com:443?sni=www.bing.com&insecure=1#${widget.selectedNode}',
        );
      }

      // Step 2: 生成 sing-box 配置
      await SingboxManager.generateConfigFromNode(
        node: _selectedNodeModel!,
        mixedPort: 15808,
      );

      // Step 3: 启动 sing-box
      bool started = await SingboxManager.start();

      if (!started) {
        if (mounted) {
          _showError('sing-box 启动失败，可能是端口被占用，正在重试...');
          
          // 等待一下再重试
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // 重试一次
          started = await SingboxManager.start();
          
          if (!started) {
            _showError('sing-box 启动失败，请检查是否有其他代理软件占用端口');
            setState(() {
              _isConnecting = false;
              _connectionStatus = '未连接';
            });
            return;
          }
        }
      }

      // Step 4: 设置系统代理
      bool proxySet = await SystemProxyHelper.setProxy('127.0.0.1', 15808);

      if (!proxySet) {
        // 代理设置失败，停止 sing-box
        await SingboxManager.stop();
        if (mounted) {
          _showError('系统代理设置失败');
          setState(() {
            _isConnecting = false;
            _connectionStatus = '未连接';
          });
        }
        return;
      }

      // 连接成功
      if (mounted) {
        setState(() {
          _connectionStatus = '已连接';
          _isConnecting = false;
        });
        widget.onConnectionStateChanged(true);
        _showSuccess('VPN 连接成功');
      }
    } catch (e) {
      if (mounted) {
        _showError('连接失败: $e');
        setState(() {
          _isConnecting = false;
          _connectionStatus = '未连接';
        });
      }
    }
  }

  /// 断开 VPN
  Future<void> _disconnectVPN() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = '断开中...';
    });
    // 通知父组件刷新 FAB
    widget.onConnectionStateChanged(widget.isProxyEnabled);

    try {
      // Step 1: 清除系统代理
      await SystemProxyHelper.clearProxy();

      // Step 2: 停止 sing-box（包含清理残留进程）
      await SingboxManager.stop();

      // 等待一下确保完全停止
      await Future.delayed(const Duration(milliseconds: 500));

      // 断开成功
      if (mounted) {
        setState(() {
          _connectionStatus = '未连接';
          _isConnecting = false;
        });
        widget.onConnectionStateChanged(false);
        _showSuccess('VPN 已断开');
      }
    } catch (e) {
      if (mounted) {
        _showError('断开失败: $e');
        setState(() {
          _isConnecting = false;
          _connectionStatus = '未连接';
        });
      }
    }
  }

  /// 显示错误提示
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: const Color(0xFFF44336),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 显示成功提示
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $message'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                            // 使用BottomSheet显示节点选择
                            NodeSelectionPage.show(
                              context,
                              selectedNode: widget.selectedNode,
                              onNodeSelected: widget.onNodeChanged,
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

              // 订阅信息加载中
              if (_userService.isLoggedIn && _isLoadingSubscribe)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                ),

              // 订阅信息卡片
              if (_userService.isLoggedIn && _subscribeInfo != null && !_isLoadingSubscribe)
                _buildSubscriptionCard(),

              if (_userService.isLoggedIn && _subscribeInfo != null && !_isLoadingSubscribe)
                const SizedBox(height: 10),

              // 功能按钮区域
              Column(
                children: [
                  // 第一行按钮
                ],
              ),
              const SizedBox(height: 100), // 底部留空给 FAB
            ],
          ),
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
    // 如果正在连接中，不处理
    if (_isConnecting) return;

    // 检查是否已登录
    if (!_userService.isLoggedIn) {
      // 未登录，跳转到登录页面
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    // 检查是否已购买订阅
    if (_subscribeInfo == null || !_subscribeInfo!.hasSubscription) {
      // 未购买订阅，提示用户购买
      _showError('请先购买VIP套餐');
      return;
    }

    // 检查订阅是否已过期
    if (_subscribeInfo!.isExpired) {
      _showError('您的订阅已过期，请续费');
      return;
    }

    // 检查流量是否用完
    if (_subscribeInfo!.remainingTraffic <= 0) {
      _showError('流量已用完，请等待重置或购买流量包');
      return;
    }

    // 已登录且已订阅，切换连接状态
    if (widget.isProxyEnabled) {
      // 当前已连接，执行断开
      _disconnectVPN();
    } else {
      // 当前未连接，执行连接
      _connectVPN();
    }
  }

}
