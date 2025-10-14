import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/node_model.dart';
import '../utils/singbox_manager.dart';

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
  static Future<void> show(
    BuildContext context, {
    required String selectedNode,
    required Function(String) onNodeSelected,
  }) async {
    await showModalBottomSheet(
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

  @override
  void initState() {
    super.initState();
    _loadNodes();
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
                // 标题
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48), // 占位，保持标题居中
                    const Text(
                      '节点选择',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF666666)),
                      onPressed: () => Navigator.pop(context),
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
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: node['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        node['type'] == 'auto' ? Icons.auto_awesome : Icons.location_on,
                        color: node['color'],
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
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
                        if (node['ping'] != '--') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getPingColor(node['ping']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              node['ping'],
                              style: TextStyle(
                                color: _getPingColor(node['ping']),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (isSelected)
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
                    ),
                    onTap: () async {
                      // 获取节点对象
                      final NodeModel? nodeModel = node['nodeModel'];
                      
                      if (nodeModel != null) {
                        // 如果有节点对象，生成配置并启动
                        try {
                          // 显示加载提示
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('正在配置节点：${node['name']}...'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          
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
                            // 通知父组件节点已选择
                            if (widget.onNodeSelected != null) {
                              widget.onNodeSelected!(node['name']);
                            }
                            
                            // 显示成功提示
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ 已连接到：${node['name']}'),
                                  backgroundColor: const Color(0xFF4CAF50),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            
                            // 关闭BottomSheet
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } else {
                            // 启动失败
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('❌ 启动失败，请查看日志'),
                                  backgroundColor: Color(0xFFF44336),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          print('❌ 配置节点失败: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ 配置失败: $e'),
                                backgroundColor: const Color(0xFFF44336),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      } else {
                        // 自动选择节点，只通知父组件
                        if (widget.onNodeSelected != null) {
                          widget.onNodeSelected!(node['name']);
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已选择：${node['name']}'),
                            backgroundColor: const Color(0xFF4CAF50),
                            duration: const Duration(milliseconds: 800),
                          ),
                        );
                        
                        Navigator.pop(context);
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

  Color _getPingColor(String ping) {
    if (ping == '--') return const Color(0xFF999999);
    
    final pingValue = int.tryParse(ping.replaceAll('ms', ''));
    if (pingValue == null) return const Color(0xFF999999);
    
    if (pingValue < 30) return const Color(0xFF4CAF50);
    if (pingValue < 80) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}