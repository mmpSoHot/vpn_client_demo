import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/node_storage_service.dart';
import '../models/node_model.dart';
import '../utils/singbox_manager.dart';
import '../utils/node_latency_tester.dart';

class NodeSelectionPage extends StatefulWidget {
  final String selectedNode;
  final Function(String)? onNodeSelected;

  const NodeSelectionPage({
    super.key,
    this.selectedNode = '自动选择',
    this.onNodeSelected,
  });

  @override
  State<NodeSelectionPage> createState() => _NodeSelectionPageState();

  /// 显示节点选择BottomSheet的静态方法
  static Future<NodeModel?> show(
    BuildContext context, {
    required String selectedNode,
    required Function(String) onNodeSelected,
  }) async {
    return await showModalBottomSheet<NodeModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NodeSelectionPage(
        selectedNode: selectedNode,
        onNodeSelected: onNodeSelected,
      ),
    );
  }
}

class _NodeSelectionPageState extends State<NodeSelectionPage> {
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  String? _errorMessage;
  bool _isTesting = false; // 是否正在测试延迟
  Map<String, int> _latencyResults = {}; // 延迟测试结果
  
  /// 在后台切换节点（不阻塞UI）
  void _switchNodeInBackground(NodeModel nodeModel, String nodeName) {
    Future(() async {
      try {
        print('🔄 后台切换节点: $nodeName');
        
        // 生成配置
        await SingboxManager.generateConfigFromNode(
          node: nodeModel,
        );
        
        // 如果已经在运行，先停止
        if (SingboxManager.isRunning()) {
          await SingboxManager.stop();
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        // 启动 sing-box
        final started = await SingboxManager.start();
        
        if (started) {
          print('✅ 节点切换成功: $nodeName');
        } else {
          print('❌ 节点切换失败: sing-box 启动失败');
        }
      } catch (e) {
        print('❌ 后台切换节点失败: $e');
      }
    });
  }

  List<Map<String, dynamic>> _nodes = [
    {
      'name': '自动选择',
      'location': '自动选择最佳节点',
      'ping': '--',
      'type': 'auto',
      'color': const Color(0xFF007AFF),
    },
    {
      'name': '香港 01',
      'location': '香港',
      'ping': '15ms',
      'type': 'premium',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': '香港 02',
      'location': '香港',
      'ping': '18ms',
      'type': 'premium',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': '新加坡 01',
      'location': '新加坡',
      'ping': '45ms',
      'type': 'premium',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': '新加坡 02',
      'location': '新加坡',
      'ping': '52ms',
      'type': 'premium',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': '日本 01',
      'location': '日本',
      'ping': '65ms',
      'type': 'premium',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': '美国 01',
      'location': '美国',
      'ping': '120ms',
      'type': 'premium',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': '美国 02',
      'location': '美国',
      'ping': '135ms',
      'type': 'premium',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': '韩国 01',
      'location': '韩国',
      'ping': '35ms',
      'type': 'premium',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': '台湾 01',
      'location': '台湾',
      'ping': '25ms',
      'type': 'premium',
      'color': const Color(0xFF4CAF50),
    },
  ];

  // ===================== 国旗 Emoji 辅助 =====================
  // 规则：
  // 1) 如果名称本身已有国旗 Emoji，则不再重复添加
  // 2) 如果名称以国家/地区字母前缀开头（如 HK/US/JP），优先使用该前缀生成国旗
  // 3) 否则根据名称/位置中的关键字做模糊映射
  String _flagForNameAndLocation(String name, String location) {
    final lowerName = name.toLowerCase();
    // 已有国旗则返回空，避免重复
    final hasFlag = RegExp(r"[\u{1F1E6}-\u{1F1FF}]{2}", unicode: true).hasMatch(name);
    if (hasFlag) return '';

    // 提取前缀字母（在空格或竖线 '|' 之前），如 "HK 香港|05|1.2x" 或 "US|01"
    final prefixMatch = RegExp(r"^([a-zA-Z]{2,3})(?=\s|\||$)").firstMatch(name);
    if (prefixMatch != null) {
      final code = prefixMatch.group(1)!.toUpperCase();
      final flag = _flagFromISO(code);
      if (flag.isNotEmpty) return flag;
    }

    // 关键字映射（名称 + 位置）
    final text = (name + ' ' + location).toLowerCase();
    if (text.contains('香港') || text.contains('hong') || text.contains(' hk')) return '🇭🇰';
    if (text.contains('台湾') || text.contains('taiwan') || text.contains(' tw')) return '🇹🇼';
    if (text.contains('新加坡') || text.contains('singapore') || text.contains(' sg')) return '🇸🇬';
    if (text.contains('日本') || text.contains('japan') || text.contains(' jp')) return '🇯🇵';
    if (text.contains('韩国') || text.contains('korea') || text.contains(' kr')) return '🇰🇷';
    if (text.contains('美国') || text.contains('usa') || text.contains(' us')) return '🇺🇸';
    if (text.contains('英国') || text.contains('united kingdom') || text.contains(' uk') || text.contains(' gb')) return '🇬🇧';
    if (text.contains('德国') || text.contains('germany') || text.contains(' de')) return '🇩🇪';
    if (text.contains('法国') || text.contains('france') || text.contains(' fr')) return '🇫🇷';
    if (text.contains('加拿大') || text.contains('canada') || text.contains(' ca')) return '🇨🇦';
    if (text.contains('澳大利亚') || text.contains('australia') || text.contains(' au')) return '🇦🇺';
    if (text.contains('印度') || text.contains('india') || text.contains(' in')) return '🇮🇳';
    if (text.contains('俄罗斯') || text.contains('russia') || text.contains(' ru')) return '🇷🇺';
    if (text.contains('巴西') || text.contains('brazil') || text.contains(' br')) return '🇧🇷';
    if (text.contains('沙特') || text.contains('saudi') || text.contains(' sa')) return '🇸🇦';
    if (text.contains('阿根廷') || text.contains('argentina') || text.contains(' ar')) return '🇦🇷';
    if (text.contains('瑞典') || text.contains('sweden') || text.contains(' se')) return '🇸🇪';
    if (text.contains('波兰') || text.contains('poland') || text.contains(' pl')) return '🇵🇱';
    if (text.contains('土耳其') || text.contains('turkey') || text.contains(' tr')) return '🇹🇷';
    if (text.contains('菲律宾') || text.contains('philippines') || text.contains(' ph')) return '🇵🇭';
    if (text.contains('泰国') || text.contains('thailand') || text.contains(' th')) return '🇹🇭';
    if (text.contains('越南') || text.contains('vietnam') || text.contains(' vn')) return '🇻🇳';
    if (text.contains('马来西亚') || text.contains('malaysia') || text.contains(' my')) return '🇲🇾';
    return '';
  }

  /// 将 ISO 两位/三位（常用两位）代码转换为国旗 Emoji（区域指示符）
  String _flagFromISO(String code) {
    final iso = code.length == 3 && code.toUpperCase() == 'UK' ? 'GB' : code.toUpperCase();
    if (iso.length < 2) return '';
    final a = iso.codeUnitAt(0);
    final b = iso.codeUnitAt(1);
    if (!(a >= 65 && a <= 90 && b >= 65 && b <= 90)) return '';
    const base = 0x1F1E6; // Regional Indicator Symbol Letter A
    final r1 = String.fromCharCode(base + (a - 65));
    final r2 = String.fromCharCode(base + (b - 65));
    return r1 + r2;
  }

  @override
  void initState() {
    super.initState();
    _loadNodes();
    _loadLatencyResults();
  }

  /// 刷新节点列表
  Future<void> _refreshNodes() async {
    await _loadNodes();
    // 刷新后可选：自动触发一次全量测试
    // await _testAllNodesLatency();
  }

  /// 加载节点列表
  Future<void> _loadNodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 获取订阅信息
      final subscribeResponse = await _apiService.getSubscribe();
      
      if (!subscribeResponse.success) {
        setState(() {
          _isLoading = false;
          _errorMessage = subscribeResponse.message ?? '获取订阅信息失败';
        });
        return;
      }

      final subscribeData = subscribeResponse.data;
      final planId = subscribeData['plan_id'];
      
      // 检查是否有订阅
      if (planId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '您还未购买订阅套餐，无法获取节点';
        });
        return;
      }

      final subscribeUrl = subscribeData['subscribe_url'];
      if (subscribeUrl == null || subscribeUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '订阅链接不存在';
        });
        return;
      }

      print('订阅链接: $subscribeUrl');

      // 获取订阅节点数据（Base64编码）
      final base64Data = await _apiService.getSubscriptionNodes(subscribeUrl);
      
      if (base64Data.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取节点数据失败';
        });
        return;
      }

      print('Base64数据长度: ${base64Data.length}');

      // 解码Base64
      String decodedData;
      try {
        decodedData = utf8.decode(base64.decode(base64Data));
        print('解码后的数据:\n$decodedData');
      } catch (e) {
        print('Base64解码失败: $e');
        setState(() {
          _isLoading = false;
          _errorMessage = '节点数据解码失败';
        });
        return;
      }

      // 解析节点
      final nodeModels = NodeModel.parseSubscriptionContent(decodedData);
      print('解析到 ${nodeModels.length} 个节点');

      // 转换为UI显示格式
      final List<Map<String, dynamic>> parsedNodes = [
        {
          'name': '自动选择',
          'location': '自动选择最佳节点',
          'ping': '--',
          'type': 'auto',
          'color': const Color(0xFF007AFF),
        },
      ];

      for (final nodeModel in nodeModels) {
        parsedNodes.add({
          'name': nodeModel.displayName,
          'location': nodeModel.location,
          'ping': '--', // 延迟需要单独测试
          'type': 'premium',
          'color': _getColorFromHex(nodeModel.colorCode),
          'protocol': nodeModel.protocol,
          'rate': nodeModel.rate,
          'nodeModel': nodeModel, // 保存完整的节点对象
        });
      }

      setState(() {
        _nodes = parsedNodes;
        _isLoading = false;
      });
    } catch (e) {
      print('加载节点失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '加载节点失败: $e';
      });
    }
  }

  /// 将十六进制颜色转换为Color对象
  Color _getColorFromHex(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return const Color(0xFF007AFF);
    }
  }

  /// 测试所有节点延迟（使用快速批量测试）
  Future<void> _testAllNodesLatency() async {
    setState(() {
      // 开始测试：清空历史结果并进入全局测试中状态
      _latencyResults.clear();
      _isTesting = true;
    });

    try {
      print('🔍 开始快速测试节点延迟...');
      
      // 只测试真实节点（跳过"自动选择"）
      final realNodes = _nodes.where((n) => n['type'] != 'auto').toList();
      
      // 提取 NodeModel 列表
      final nodeModels = realNodes
          .map((n) => n['nodeModel'] as NodeModel?)
          .where((n) => n != null)
          .cast<NodeModel>()
          .toList();
      
      if (nodeModels.isEmpty) {
        print('⚠️ 没有可测试的节点');
        return;
      }

      // 使用快速批量测试（全并发）
      final results = await NodeLatencyTester.testMultipleNodes(nodeModels);
      
      // 转换结果：使用 displayName 作为 key（因为 UI 显示时用的是 displayName）
      final convertedResults = <String, int>{};
      for (final nodeModel in nodeModels) {
        final originalKey = nodeModel.name;  // 测试结果的 key
        final displayKey = nodeModel.displayName;  // UI 显示的 key
        if (results.containsKey(originalKey)) {
          convertedResults[displayKey] = results[originalKey]!;
        }
      }
      
      // 更新结果
      setState(() {
        _latencyResults = convertedResults;
      });

      print('✅ 延迟测试完成，成功显示 ${convertedResults.length} 个节点的延迟');
      
      // 保存延迟结果
      await _saveLatencyResults();
      
    } catch (e) {
      print('❌ 测试延迟失败: $e');
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('测试失败: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  // 单个节点测试已移除，仅保留批量测试

  /// 保存延迟结果
  Future<void> _saveLatencyResults() async {
    try {
      final prefs = await NodeStorageService.getPreferences();
      await prefs.setString('node_latency_results', jsonEncode(_latencyResults));
    } catch (e) {
      print('❌ 保存延迟结果失败: $e');
    }
  }

  /// 加载延迟结果
  Future<void> _loadLatencyResults() async {
    try {
      final prefs = await NodeStorageService.getPreferences();
      final resultsJson = prefs.getString('node_latency_results');
      if (resultsJson != null) {
        final results = jsonDecode(resultsJson) as Map<String, dynamic>;
        setState(() {
          _latencyResults = results.map((k, v) => MapEntry(k, v as int));
        });
        print('📌 已加载延迟测试结果');
      }
    } catch (e) {
      print('❌ 加载延迟结果失败: $e');
    }
  }

  /// 获取节点显示的延迟
  String _getNodeLatency(String nodeName) {
    if (nodeName == '自动选择') return '--';
    
    final latency = _latencyResults[nodeName];
    if (latency == null) return '--';
    
    return NodeLatencyTester.formatLatency(latency);
  }

  /// 获取节点延迟颜色
  Color _getLatencyColor(String nodeName) {
    if (nodeName == '自动选择') return const Color(0xFF999999);
    
    final latency = _latencyResults[nodeName] ?? 0;
    return NodeLatencyTester.getLatencyColor(latency);
  }


  @override
  Widget build(BuildContext context) {
    // 获取屏幕高度，BottomSheet高度为屏幕的80%
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 顶部拖动条和标题
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // 拖动指示条
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                // 标题和操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 左侧：更新节点
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, color: Color(0xFF007AFF)),
                      onPressed: _isLoading ? null : _refreshNodes,
                      tooltip: '更新节点',
                    ),
                    // 中间标题
                    const Text(
                      '节点选择',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // 右侧：测试连接与关闭组合
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.speed, color: Color(0xFF007AFF)),
                          onPressed: _isTesting ? null : _testAllNodesLatency,
                          tooltip: '测试连接',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF666666)),
                          onPressed: () => Navigator.pop(context),
                          tooltip: '关闭',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // 节点列表
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          '正在加载节点...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loadNodes,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('重新加载'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _nodes.length,
                        itemBuilder: (context, index) {
                final node = _nodes[index];
                final isSelected = widget.selectedNode == node['name'];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? node['color'] : const Color(0xFFE0E0E0),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         
                    title: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              // 国旗 Emoji（根据名称/位置推断）
                              Builder(builder: (_) {
                                final flag = _flagForNameAndLocation(
                                  node['name']?.toString() ?? '',
                                  node['location']?.toString() ?? '',
                                );
                                return flag.isEmpty
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Text(
                                          flag,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      );
                              }),
                              Expanded(
                                child: Text(
                                  node['name'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? node['color'] : const Color(0xFF333333),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (node['protocol'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              node['protocol'],
                              style: const TextStyle(
                                color: Color(0xFF007AFF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (node['rate'] != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${node['rate']}x',
                              style: const TextStyle(
                                color: Color(0xFFFF9800),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      node['location'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 延迟显示 / 测试中占位
                        Builder(builder: (_) {
                          final text = _getNodeLatency(node['name']);
                          // 数字统一使用绿色显示
                          const textColor = Color(0xFF4CAF50);
                          final isTesting = _isTesting && (text == '--');
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: isTesting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    text,
                                    style: const TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          );
                        }),
                        // 仅显示延迟，不提供单个节点测试按钮
                        // 选中标记
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: node['color'],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      // 获取节点对象
                      final NodeModel? nodeModel = node['nodeModel'];
                      
                      // 立即关闭 BottomSheet 并返回节点对象
                      Navigator.pop(context, nodeModel);
                      
                      // 通知父组件节点已选择
                      if (widget.onNodeSelected != null) {
                        widget.onNodeSelected!(node['name']);
                      }
                      
                      if (nodeModel != null) {
                        // 显示切换提示
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('正在切换到：${node['name']}...'),
                            backgroundColor: const Color(0xFF2196F3),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                        
                        // 在后台异步执行重启操作，不阻塞UI
                        _switchNodeInBackground(nodeModel, node['name']);
                      } else {
                        // 自动选择节点
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已选择：${node['name']}'),
                            backgroundColor: const Color(0xFF4CAF50),
                            duration: const Duration(milliseconds: 800),
                          ),
                        );
                      }
                    },
                  ),
                );
                        },
                      ),
          ),
        ],
      ),
    );
  }

}