import 'package:flutter/material.dart';

class ProxyModePage extends StatefulWidget {
  const ProxyModePage({super.key});

  @override
  State<ProxyModePage> createState() => _ProxyModePageState();
}

class _ProxyModePageState extends State<ProxyModePage> {
  String _selectedMode = '全局模式';

  final List<Map<String, dynamic>> _proxyModes = [
    {
      'name': '全局模式',
      'description': '所有网络流量都通过代理',
      'icon': Icons.public,
      'color': const Color(0xFF007AFF),
    },
    {
      'name': '智能模式',
      'description': '仅国外网站通过代理',
      'icon': Icons.psychology,
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': '规则模式',
      'description': '根据自定义规则选择代理',
      'icon': Icons.rule,
      'color': const Color(0xFFFF9800),
    },
    {
      'name': '直连模式',
      'description': '不通过代理直接连接',
      'icon': Icons.wifi,
      'color': const Color(0xFF9C27B0),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '代理模式',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 说明文字
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2196F3), width: 1),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '选择适合您的代理模式，不同模式适用于不同场景',
                    style: TextStyle(
                      color: Color(0xFF1976D2),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 模式列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _proxyModes.length,
              itemBuilder: (context, index) {
                final mode = _proxyModes[index];
                final isSelected = _selectedMode == mode['name'];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? mode['color'] : const Color(0xFFE0E0E0),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: mode['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        mode['icon'],
                        color: mode['color'],
                        size: 24,
                      ),
                    ),
                    title: Text(
                      mode['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? mode['color'] : const Color(0xFF333333),
                      ),
                    ),
                    subtitle: Text(
                      mode['description'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: mode['color'],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedMode = mode['name'];
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
                  // 保存选择的模式
                  Navigator.pop(context, _selectedMode);
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
} 