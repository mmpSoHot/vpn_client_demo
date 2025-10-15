import 'dart:async';
import 'dart:io';  // 用于平台判断
import 'package:flutter/material.dart';
import 'node_selection_page.dart';
import 'vip_recharge_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import '../services/user_service.dart';
import '../services/proxy_mode_service.dart';
import '../services/api_service.dart';
import '../services/node_storage_service.dart';
import '../services/websocket_speed_service.dart';
import '../models/subscribe_model.dart';
import '../models/node_model.dart';
import '../utils/auth_helper.dart';
import '../utils/singbox_manager.dart';
import '../utils/system_proxy_helper.dart';
import '../utils/android_vpn_helper.dart';  // Android VPN 支持

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
  // 出站模式状态改由 HomeContent 内部管理

  @override
  void initState() {
    super.initState();
    // 监听用户服务状态变化
    _userService.addListener(_onUserServiceChanged);
    // 加载上次选择的节点
    _loadLastSelectedNode();
    // 出站模式由子组件加载
  }

  

  /// 加载上次选择的节点
  Future<void> _loadLastSelectedNode() async {
    final savedNodeName = await NodeStorageService.getSelectedNodeName();
    if (savedNodeName != null && savedNodeName.isNotEmpty) {
      setState(() {
        _selectedNode = savedNodeName;
      });
      print('📌 恢复上次选择的节点: $savedNodeName');
    }
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

  void _updateSelectedNode(String nodeName) async {
    if (mounted) {
      setState(() {
        _selectedNode = nodeName;
      });

      // 保存节点选择（仅保存名称，后续优化时可保存完整节点数据）
      // 创建一个临时节点用于保存
      final tempNode = NodeModel(
        name: nodeName,
        protocol: 'Hysteria2',
        location: '未知',
        rawConfig: '',
      );
      await NodeStorageService.saveSelectedNode(tempNode);

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
        actions: const [],
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
  ProxyMode _proxyMode = ProxyMode.bypassCN; // 出站模式（本地状态）
  final WebSocketSpeedService _speedService = WebSocketSpeedService(); // 网速监控服务

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
    // 加载出站模式
    _loadProxyModeLocal();
    // 加载上次选择的节点对象
    _loadSavedNode();
    // 监听网速变化
    _speedService.uploadSpeedNotifier.addListener(_onSpeedUpdate);
    _speedService.downloadSpeedNotifier.addListener(_onSpeedUpdate);
  }

  Future<void> _loadProxyModeLocal() async {
    _proxyMode = await ProxyModeService.getMode();
    if (mounted) setState(() {});
  }
  
  /// 加载保存的节点对象
  Future<void> _loadSavedNode() async {
    try {
      print('🔍 [HomeContent] 开始加载保存的节点对象...');
      final savedNode = await NodeStorageService.getSelectedNode();
      
      if (savedNode == null) {
        print('⚠️ [HomeContent] 没有找到保存的节点对象');
        return;
      }
      
      if (savedNode.rawConfig.isEmpty) {
        print('⚠️ [HomeContent] 节点配置为空: ${savedNode.name}');
        return;
      }
      
      setState(() {
        _selectedNodeModel = savedNode;
      });
      print('✅ [HomeContent] 恢复上次选择的节点对象: ${savedNode.displayName}');
      print('   协议: ${savedNode.protocol}');
      print('   配置长度: ${savedNode.rawConfig.length}');
    } catch (e) {
      print('❌ [HomeContent] 加载保存的节点失败: $e');
      print('   错误堆栈: ${StackTrace.current}');
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
    // 停止状态检查
    _statusChecker?.cancel();
    // 移除网速监听器
    _speedService.uploadSpeedNotifier.removeListener(_onSpeedUpdate);
    _speedService.downloadSpeedNotifier.removeListener(_onSpeedUpdate);
    super.dispose();
  }

  void _onUserServiceChanged() {
    // 当用户服务状态改变时，刷新页面
    if (mounted) {
      setState(() {});
    }
  }

  void _onSpeedUpdate() {
    // 网速更新时刷新UI
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

      bool isConnected = false;
      
      if (Platform.isAndroid) {
        // Android: 检查 VPN 服务状态
        isConnected = await AndroidVpnHelper.isRunning();
      } else if (Platform.isWindows) {
        // Windows: 检查 sing-box 进程和系统代理
        bool singboxRunning = SingboxManager.isRunning();
        bool proxySet = await SystemProxyHelper.isProxySetTo('127.0.0.1', 15808);
        isConnected = singboxRunning && proxySet;
        
        // 如果 sing-box 意外停止，清除系统代理
        if (!singboxRunning && proxySet) {
          print('⚠️ 检测到 sing-box 异常停止，清除系统代理');
          await SystemProxyHelper.clearProxy();
        }
      }

      if (mounted && widget.isProxyEnabled != isConnected) {
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
      // Step 1: 获取节点
      print('🔍 [连接] 检查节点: _selectedNodeModel = ${_selectedNodeModel?.displayName ?? "null"}');
      
      if (_selectedNodeModel == null) {
        print('⚠️ [连接] 内存中没有节点对象，尝试从存储加载...');
        
        // 尝试从存储中加载上次选择的节点
        final savedNode = await NodeStorageService.getSelectedNode();
        
        if (savedNode != null && savedNode.rawConfig.isNotEmpty) {
          // 使用保存的节点
          _selectedNodeModel = savedNode;
          print('✅ [连接] 从存储加载节点成功: ${savedNode.displayName}');
        } else {
          // 如果没有保存的节点，提示用户先选择节点
          print('❌ [连接] 存储中也没有节点，savedNode = $savedNode');
          if (savedNode != null) {
            print('   节点名称: ${savedNode.name}');
            print('   rawConfig 是否为空: ${savedNode.rawConfig.isEmpty}');
          }
          
          if (mounted) {
            _showError('请先选择节点');
            setState(() {
              _isConnecting = false;
              _connectionStatus = '未连接';
            });
          }
          return;
        }
      } else {
        print('✅ [连接] 使用内存中的节点: ${_selectedNodeModel!.displayName}');
      }

      // Step 2: 根据平台启动 VPN
      bool started = false;
      
      if (Platform.isWindows) {
        // Windows 平台：使用 sing-box.exe + 系统代理
        await SingboxManager.generateConfigFromNode(
          node: _selectedNodeModel!,
          mixedPort: 15808,
          proxyMode: _proxyMode,
        );
        
        started = await SingboxManager.start();
        
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
        
        // Step 3: 设置系统代理
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
        
        started = true;
      } else if (Platform.isAndroid) {
        // Android 平台：使用 VPN 服务 + TUN 接口
        print('🤖 Android 平台，使用 VPN 服务');
        
        // Step 1: 检查 VPN 权限
        bool hasPermission = await AndroidVpnHelper.checkPermission();
        if (!hasPermission) {
          if (mounted) {
            _showError('正在请求 VPN 权限...');
          }
          
          hasPermission = await AndroidVpnHelper.requestPermission();
          
          if (!hasPermission) {
            if (mounted) {
              _showError('需要 VPN 权限才能使用，请在系统设置中授予权限');
              setState(() {
                _isConnecting = false;
                _connectionStatus = '未连接';
              });
            }
            return;
          }
        }
        
        // Step 2: 启动 VPN 服务
        started = await AndroidVpnHelper.startVpn(
          node: _selectedNodeModel!,
          proxyMode: _proxyMode,
        );
        
        if (!started) {
          if (mounted) {
            _showError('Android VPN 启动失败，请检查 libbox.aar 是否已配置');
            setState(() {
              _isConnecting = false;
              _connectionStatus = '未连接';
            });
          }
          return;
        }
      } else {
        // 其他平台暂不支持
        if (mounted) {
          _showError('当前平台暂不支持，仅支持 Windows 和 Android');
          setState(() {
            _isConnecting = false;
            _connectionStatus = '未连接';
          });
        }
        return;
      }

      // 连接成功检查
      if (!started) {
        if (mounted) {
          _showError('VPN 启动失败');
          setState(() {
            _isConnecting = false;
            _connectionStatus = '未连接';
          });
        }
        return;
      }

      // Step 4: 连接成功
      if (mounted) {
        setState(() {
          _connectionStatus = '已连接';
          _isConnecting = false;
        });
        widget.onConnectionStateChanged(true);
        _showSuccess('VPN 连接成功');
        
        // 延迟启动 WebSocket 监控，确保 sing-box 完全启动并启用 API
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && widget.isProxyEnabled) {
            print('🚀 启动网速监控服务...');
            _speedService.startMonitoring();
          }
        });
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
      if (Platform.isWindows) {
        // Windows 平台：清除系统代理 + 停止 sing-box
        await SystemProxyHelper.clearProxy();
        await SingboxManager.stop();
        
        // 等待一下确保完全停止
        await Future.delayed(const Duration(milliseconds: 500));
      } else if (Platform.isAndroid) {
        // Android 平台：停止 VPN 服务
        await AndroidVpnHelper.stopVpn();
      }

      // 断开成功
      if (mounted) {
        setState(() {
          _connectionStatus = '未连接';
          _isConnecting = false;
        });
        widget.onConnectionStateChanged(false);
        _showSuccess('VPN 已断开');
        
        // 停止网速监控
        _speedService.stopMonitoring();
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

  /// 应用代理模式更改（VPN 运行时）
  Future<void> _applyProxyModeChange() async {
    try {
      print('🔄 正在应用代理模式更改...');
      
      if (Platform.isWindows) {
        // Windows 平台：重新生成配置并重启 sing-box
        
        // 1. 重新生成配置
        await SingboxManager.generateConfigFromNode(
          node: _selectedNodeModel!,
          mixedPort: 15808,
          proxyMode: _proxyMode,
        );
        
        // 2. 停止 sing-box
        await SingboxManager.stop();
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 3. 重新启动 sing-box
        bool started = await SingboxManager.start();
        
        if (!started) {
          throw Exception('重启 sing-box 失败');
        }
      } else if (Platform.isAndroid) {
        // Android 平台：重新启动 VPN 服务
        
        // 1. 停止 VPN
        await AndroidVpnHelper.stopVpn();
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 2. 重新启动 VPN
        bool started = await AndroidVpnHelper.startVpn(
          node: _selectedNodeModel!,
          proxyMode: _proxyMode,
        );
        
        if (!started) {
          throw Exception('重启 Android VPN 失败');
        }
      }
      
      print('✅ 代理模式更改已应用');
    } catch (e) {
      print('❌ 应用代理模式失败: $e');
      if (mounted) {
        _showError('切换模式失败: $e');
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
          // 功能区块（出站模式 + 流量统计）
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.extension, color: Color(0xFF007AFF), size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    '功能',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // 出站模式卡片
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      constraints: const BoxConstraints(minHeight: 132),
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
                        const Text(
                            '出站模式',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                          const SizedBox(height: 8),
                          RadioListTile<ProxyMode>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: ProxyMode.bypassCN,
                            groupValue: _proxyMode,
                            title: const Text('绕过大陆'),
                            subtitle: const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                '国内直连，其它走代理',
                                style: TextStyle(fontSize: 12, color: Color(0xFF888888), height: 1.2),
                              ),
                            ),
                            onChanged: (v) async {
                              if (v == null) return;
                              setState(() => _proxyMode = v);
                              await ProxyModeService.setMode(v);
                              
                              // 如果 VPN 正在运行，重新生成配置并重启 sing-box
                              if (widget.isProxyEnabled && _selectedNodeModel != null) {
                                await _applyProxyModeChange();
                              }
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已切换为: 绕过大陆')),
                                );
                              }
                            },
                          ),                       
                          RadioListTile<ProxyMode>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: ProxyMode.global,
                            groupValue: _proxyMode,
                            title: const Text('全局代理'),
                            subtitle: const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                '全部流量走代理',
                                style: TextStyle(fontSize: 12, color: Color(0xFF888888), height: 1.2),
                              ),
                            ),
                            onChanged: (v) async {
                              if (v == null) return;
                              setState(() => _proxyMode = v);
                              await ProxyModeService.setMode(v);
                              
                              // 如果 VPN 正在运行，重新生成配置并重启 sing-box
                              if (widget.isProxyEnabled && _selectedNodeModel != null) {
                                await _applyProxyModeChange();
                              }
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已切换为: 全局代理')),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.6),
                  // 流量统计卡片（占位）
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      constraints: const BoxConstraints(minHeight: 132),
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
                          const Text(
                            '流量统计',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 左侧圆环
                              SizedBox(
                                width: 52,
                                height: 52,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: const [
                                    SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 8,
                                        value: 0.72,
                                        color: Color(0xFF8FA6D9), // 下载色（示意）
                                        backgroundColor: Color(0xFFE5E7EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 右侧颜色说明
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        // 上传颜色方块
                                        SizedBox(
                                          width: 14,
                                          height: 8,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(color: Color(0xFFC8CCD2), borderRadius: BorderRadius.all(Radius.circular(2))),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text('上传', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                      ],
                                    ),                            
                                    Row(
                                      children: const [
                                        // 下载颜色方块
                                        SizedBox(
                                          width: 14,
                                          height: 8,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(color: Color(0xFF8FA6D9), borderRadius: BorderRadius.all(Radius.circular(2))),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text('下载', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 实时速度（上传/下载），单位靠右
                          ValueListenableBuilder<String>(
                            valueListenable: _speedService.uploadSpeedNotifier,
                            builder: (context, uploadSpeed, child) {
                              return Row(
                                children: [
                                  const Icon(Icons.arrow_upward, size: 14, color: Color(0xFFC8CCD2)),
                                  const SizedBox(width: 8),
                                  Expanded(
                          child: Text(
                                      uploadSpeed.replaceAll('/s', ''),
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                                    ),
                                  ),
                                  const Text('/s', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<String>(
                            valueListenable: _speedService.downloadSpeedNotifier,
                            builder: (context, downloadSpeed, child) {
                              return Row(
                                children: [
                                  const Icon(Icons.arrow_downward, size: 14, color: Color(0xFF8FA6D9)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      downloadSpeed.replaceAll('/s', ''),
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                                    ),
                                  ),
                                  const Text('/s', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                          onTap: () async {
                            // 使用BottomSheet显示节点选择
                            final selectedNodeModel = await NodeSelectionPage.show(
                              context,
                              selectedNode: widget.selectedNode,
                              onNodeSelected: widget.onNodeChanged,
                            );
                            
                            // 如果用户选择了节点，更新当前选中的节点对象
                            if (selectedNodeModel != null) {
                              setState(() {
                                _selectedNodeModel = selectedNodeModel;
                              });
                              
                              // 保存节点对象到持久化存储
                              await NodeStorageService.saveSelectedNode(selectedNodeModel);
                              
                              print('✅ 已选择节点: ${selectedNodeModel.displayName}');
                              print('💾 节点已保存，rawConfig 长度: ${selectedNodeModel.rawConfig.length}');
                            }
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
