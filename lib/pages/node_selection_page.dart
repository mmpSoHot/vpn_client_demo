import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import '../services/api_service.dart';
import '../services/node_storage_service.dart';
import '../models/node_model.dart';
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

  // ===================== 国旗代码提取 =====================
  /// 从节点名称和位置提取国家代码（用于 country_flags 包）
  /// 返回 2 字母国家代码，如 'HK', 'US', 'JP'
  String? _getCountryCode(String name, String location) {
    // 先检查名称中是否有 Emoji 国旗（如果有就提取代码）
    final emojiMatch = RegExp(r"[\u{1F1E6}-\u{1F1FF}]", unicode: true).firstMatch(name);
    if (emojiMatch != null) {
      // 如果有 Emoji，提取对应的国家代码
      final emoji = name.substring(emojiMatch.start, emojiMatch.start + 2);
      return _countryCodeFromEmoji(emoji);
    }

    // 提取前缀字母（在空格或竖线 '|' 之前），如 "HK 香港|05|1.2x" 或 "US|01"
    final prefixMatch = RegExp(r"^([a-zA-Z]{2,3})(?=\s|\||$)").firstMatch(name);
    if (prefixMatch != null) {
      final code = prefixMatch.group(1)!.toUpperCase();
      if (code == 'UK') return 'GB'; // UK 用 GB 代码
      if (code.length == 2) return code;
    }

    // 关键字映射（名称 + 位置）
    final text = (name + ' ' + location).toLowerCase();
    if (text.contains('香港') || text.contains('hong')) return 'HK';
    if (text.contains('台湾') || text.contains('taiwan')) return 'TW';
    if (text.contains('新加坡') || text.contains('singapore')) return 'SG';
    if (text.contains('日本') || text.contains('japan')) return 'JP';
    if (text.contains('韩国') || text.contains('korea')) return 'KR';
    if (text.contains('美国') || text.contains('usa') || text.contains('america')) return 'US';
    if (text.contains('英国') || text.contains('kingdom')) return 'GB';
    if (text.contains('德国') || text.contains('germany')) return 'DE';
    if (text.contains('法国') || text.contains('france')) return 'FR';
    if (text.contains('加拿大') || text.contains('canada')) return 'CA';
    if (text.contains('澳大利亚') || text.contains('australia')) return 'AU';
    if (text.contains('印度') || text.contains('india')) return 'IN';
    if (text.contains('俄罗斯') || text.contains('russia')) return 'RU';
    if (text.contains('巴西') || text.contains('brazil')) return 'BR';
    if (text.contains('沙特') || text.contains('saudi')) return 'SA';
    if (text.contains('阿根廷') || text.contains('argentina')) return 'AR';
    if (text.contains('瑞典') || text.contains('sweden')) return 'SE';
    if (text.contains('波兰') || text.contains('poland')) return 'PL';
    if (text.contains('土耳其') || text.contains('turkey')) return 'TR';
    if (text.contains('菲律宾') || text.contains('philippines')) return 'PH';
    if (text.contains('泰国') || text.contains('thailand')) return 'TH';
    if (text.contains('越南') || text.contains('vietnam')) return 'VN';
    if (text.contains('马来西亚') || text.contains('malaysia')) return 'MY';
    if (text.contains('芬兰') || text.contains('finland')) return 'FI';
    if (text.contains('塞尔维亚') || text.contains('serbia')) return 'RS';
    if (text.contains('立陶宛') || text.contains('lithuania')) return 'LT';
    if (text.contains('波黑') || text.contains('bosnia')) return 'BA';
    if (text.contains('保加利亚') || text.contains('bulgaria')) return 'BG';
    return null;
  }

  /// 从 Emoji 国旗提取国家代码
  String? _countryCodeFromEmoji(String emoji) {
    if (emoji.length < 2) return null;
    const base = 0x1F1E6;
    final a = emoji.codeUnitAt(0) - base;
    final b = emoji.codeUnitAt(1) - base;
    if (a < 0 || a > 25 || b < 0 || b > 25) return null;
    return String.fromCharCode(65 + a) + String.fromCharCode(65 + b);
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
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: _nodes.length,
                        itemBuilder: (context, index) {
                final node = _nodes[index];
                final isSelected = widget.selectedNode == node['name'];
                
                return Container(
                  decoration: BoxDecoration(
                    color: isSelected ? node['color'].withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? node['color'] : const Color(0xFFE5E7EB),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final NodeModel? nodeModel = node['nodeModel'];
                        Navigator.pop(context, nodeModel);
                        if (widget.onNodeSelected != null) {
                          widget.onNodeSelected!(node['name']);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 顶部：国旗 + 节点名称
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 国旗图标
                                Builder(builder: (_) {
                                  final countryCode = _getCountryCode(
                                    node['name']?.toString() ?? '',
                                    node['location']?.toString() ?? '',
                                  );
                                  if (countryCode == null) return const SizedBox.shrink();
                                  
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: CountryFlag.fromCountryCode(
                                      countryCode,
                                      theme: const ImageTheme(
                                        width: 24,
                                        height: 18,
                                        shape: RoundedRectangle(3),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    node['name'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? node['color'] : const Color(0xFF1F2937),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // 中间：协议 + 倍率
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (node['protocol'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      node['protocol'],
                                      style: const TextStyle(
                                        color: Color(0xFF6366F1),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (node['rate'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${node['rate']}x',
                                      style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            // 底部：延迟 + 选中标记
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Builder(builder: (_) {
                                  final text = _getNodeLatency(node['name']);
                                  final isTesting = _isTesting && (text == '--');
                                  
                                  if (isTesting) {
                                    return const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF6366F1),
                                      ),
                                    );
                                  }
                                  
                                  return Text(
                                    text,
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: node['color'],
                                    size: 20,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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