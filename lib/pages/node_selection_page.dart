import 'package:flutter/material.dart';

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
}

class _NodeSelectionPageState extends State<NodeSelectionPage> {
  String _selectedNode = '自动选择';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _nodes = [
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
    _selectedNode = widget.selectedNode;
  }

  List<Map<String, dynamic>> get _filteredNodes {
    if (_searchQuery.isEmpty) {
      return _nodes;
    }
    return _nodes.where((node) {
      return node['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             node['location'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // 搜索框
          Container(
            margin: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索节点...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF999999)),
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
                fillColor: Colors.white,
              ),
            ),
          ),
          
          // 节点列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredNodes.length,
              itemBuilder: (context, index) {
                final node = _filteredNodes[index];
                final isSelected = _selectedNode == node['name'];
                
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
                        Text(
                          node['name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? node['color'] : const Color(0xFF333333),
                          ),
                        ),
                        if (node['type'] == 'premium') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                color: Color(0xFF333333),
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
                    onTap: () {
                      setState(() {
                        _selectedNode = node['name'];
                      });
                    },
                  ),
                );
              },
            ),
          ),
          
          // 确认按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  _confirmNodeSelection();
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
                  '确认选择',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmNodeSelection() {
    // 通知父页面更新选中的节点
    if (widget.onNodeSelected != null) {
      widget.onNodeSelected!(_selectedNode);
    }
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