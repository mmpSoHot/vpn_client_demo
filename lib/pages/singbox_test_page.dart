import 'package:flutter/material.dart';
import '../utils/singbox_manager.dart';

class SingboxTestPage extends StatefulWidget {
  const SingboxTestPage({super.key});

  @override
  State<SingboxTestPage> createState() => _SingboxTestPageState();
}

class _SingboxTestPageState extends State<SingboxTestPage> {
  bool _isRunning = false;
  String _status = '未运行';
  String _singboxPath = '';
  String _configPath = '';

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  void _loadPaths() {
    try {
      setState(() {
        _singboxPath = SingboxManager.getSingboxPath();
        _configPath = SingboxManager.getConfigPath();
      });
    } catch (e) {
      setState(() {
        _status = '错误: $e';
      });
    }
  }

  Future<void> _generateConfig() async {
    try {
      await SingboxManager.generateConfig(
        nodeUrl: 'vmess://xxx', // 这里需要实际的节点URL
        nodeName: '测试节点',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 配置文件已生成')),
        );
      }
      
      setState(() {
        _status = '配置已生成';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 生成配置失败: $e')),
        );
      }
    }
  }

  Future<void> _start() async {
    setState(() {
      _status = '正在启动...';
    });

    final success = await SingboxManager.start();
    
    setState(() {
      _isRunning = success;
      _status = success ? '运行中' : '启动失败';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ 启动成功' : '❌ 启动失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _stop() async {
    setState(() {
      _status = '正在停止...';
    });

    final success = await SingboxManager.stop();
    
    setState(() {
      _isRunning = false;
      _status = success ? '已停止' : '停止失败';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ 已停止' : '❌ 停止失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _restart() async {
    setState(() {
      _status = '正在重启...';
    });

    final success = await SingboxManager.restart();
    
    setState(() {
      _isRunning = success;
      _status = success ? '运行中' : '重启失败';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ 重启成功' : '❌ 重启失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sing-box 测试'),
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isRunning ? Icons.check_circle : Icons.cancel,
                          color: _isRunning ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '状态: $_status',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('sing-box.exe: $_singboxPath'),
                    const SizedBox(height: 8),
                    Text('配置文件: $_configPath'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 操作按钮
            const Text(
              '操作',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 生成配置按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateConfig,
                icon: const Icon(Icons.settings),
                label: const Text('生成配置文件'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 启动按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('启动 sing-box'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 停止按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? _stop : null,
                icon: const Icon(Icons.stop),
                label: const Text('停止 sing-box'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 重启按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? _restart : null,
                icon: const Icon(Icons.refresh),
                label: const Text('重启 sing-box'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const Spacer(),
            
            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 提示:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('1. 首先点击"生成配置文件"'),
                  Text('2. 然后点击"启动 sing-box"'),
                  Text('3. 查看控制台输出以了解运行状态'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

