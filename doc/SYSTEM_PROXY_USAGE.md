# 系统代理管理使用指南

## 📦 依赖安装

已在 `pubspec.yaml` 中添加：
```yaml
dependencies:
  win32: ^5.1.0
  ffi: ^2.1.0
  path: ^1.9.0
```

安装依赖：
```bash
flutter pub get
```

## 🎯 基本使用

### 1. 导入工具类

```dart
import 'package:demo2/utils/system_proxy_helper.dart';
```

### 2. 设置系统代理

```dart
// 设置代理到 127.0.0.1:15808
bool success = await SystemProxyHelper.setProxy('127.0.0.1', 15808);

if (success) {
  print('✅ 系统代理设置成功');
} else {
  print('❌ 系统代理设置失败');
}
```

### 3. 清除系统代理

```dart
// 清除系统代理
bool success = await SystemProxyHelper.clearProxy();

if (success) {
  print('✅ 系统代理已清除');
} else {
  print('❌ 系统代理清除失败');
}
```

### 4. 获取当前代理状态

```dart
// 获取当前系统代理状态
ProxyStatus status = await SystemProxyHelper.getProxyStatus();

print('代理启用: ${status.enabled}');
print('代理服务器: ${status.server}');

// 检查是否指向特定地址
bool isSet = await SystemProxyHelper.isProxySetTo('127.0.0.1', 15808);
print('代理是否指向 127.0.0.1:15808: $isSet');
```

## 🔧 集成到首页

### 方案 1: 简单集成（推荐）

修改 `lib/pages/home_page.dart`：

```dart
import 'package:demo2/utils/system_proxy_helper.dart';
import 'package:demo2/utils/singbox_manager.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isConnected = false;
  bool isConnecting = false;
  
  // VPN 连接/断开
  Future<void> onToggleConnection(bool value) async {
    if (isConnecting) return;
    
    setState(() => isConnecting = true);
    
    try {
      if (value) {
        await _connect();
      } else {
        await _disconnect();
      }
    } finally {
      setState(() => isConnecting = false);
    }
  }
  
  // 连接 VPN
  Future<void> _connect() async {
    // Step 1: 生成配置
    await SingboxManager.generateConfigFromNode(
      node: selectedNode,  // 你选中的节点
      mixedPort: 15808,
    );
    
    // Step 2: 启动 sing-box
    bool started = await SingboxManager.start();
    
    if (!started) {
      _showError('sing-box 启动失败');
      return;
    }
    
    // Step 3: 设置系统代理
    bool proxySet = await SystemProxyHelper.setProxy('127.0.0.1', 15808);
    
    if (!proxySet) {
      _showError('系统代理设置失败');
      await SingboxManager.stop();
      return;
    }
    
    setState(() => isConnected = true);
    _showSuccess('VPN 已连接');
  }
  
  // 断开 VPN
  Future<void> _disconnect() async {
    // Step 1: 清除系统代理
    await SystemProxyHelper.clearProxy();
    
    // Step 2: 停止 sing-box
    await SingboxManager.stop();
    
    setState(() => isConnected = false);
    _showSuccess('VPN 已断开');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('VPN 客户端')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // VPN 连接开关
            SwitchListTile(
              title: Text('VPN 连接'),
              subtitle: Text(isConnected ? '已连接 ✅' : '未连接'),
              value: isConnected,
              onChanged: isConnecting ? null : onToggleConnection,
            ),
            
            if (isConnecting)
              Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $message'), backgroundColor: Colors.green),
    );
  }
}
```

### 方案 2: 分离控制（高级）

如果你想要独立的 VPN 开关和系统代理开关：

```dart
class _HomePageState extends State<HomePage> {
  bool isSingboxRunning = false;
  bool isSystemProxySet = false;
  
  // Sing-box 开关
  Future<void> onToggleSingbox(bool value) async {
    if (value) {
      await SingboxManager.generateConfigFromNode(...);
      bool started = await SingboxManager.start();
      setState(() => isSingboxRunning = started);
    } else {
      await SingboxManager.stop();
      setState(() => isSingboxRunning = false);
    }
  }
  
  // 系统代理开关
  Future<void> onToggleSystemProxy(bool value) async {
    if (value) {
      bool success = await SystemProxyHelper.setProxy('127.0.0.1', 15808);
      setState(() => isSystemProxySet = success);
    } else {
      await SystemProxyHelper.clearProxy();
      setState(() => isSystemProxySet = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sing-box 核心开关
        SwitchListTile(
          title: Text('Sing-box 核心'),
          subtitle: Text(isSingboxRunning ? '运行中' : '已停止'),
          value: isSingboxRunning,
          onChanged: onToggleSingbox,
        ),
        
        // 系统代理开关
        SwitchListTile(
          title: Text('系统代理'),
          subtitle: Text(isSystemProxySet ? '已启用' : '未启用'),
          value: isSystemProxySet,
          onChanged: onToggleSystemProxy,
          // 只有在 sing-box 运行时才能设置系统代理
          enabled: isSingboxRunning,
        ),
      ],
    );
  }
}
```

## 🔄 状态监控

添加定时检查，确保状态同步：

```dart
class _HomePageState extends State<HomePage> {
  Timer? _statusChecker;
  
  @override
  void initState() {
    super.initState();
    _startStatusChecker();
  }
  
  @override
  void dispose() {
    _statusChecker?.cancel();
    super.dispose();
  }
  
  void _startStatusChecker() {
    _statusChecker = Timer.periodic(Duration(seconds: 3), (timer) async {
      // 检查 sing-box 是否还在运行
      bool singboxRunning = SingboxManager.isRunning();
      
      // 检查系统代理状态
      ProxyStatus proxyStatus = await SystemProxyHelper.getProxyStatus();
      bool proxySet = await SystemProxyHelper.isProxySetTo('127.0.0.1', 15808);
      
      // 更新状态
      if (mounted) {
        setState(() {
          isConnected = singboxRunning && proxySet;
        });
      }
      
      // 如果 sing-box 意外停止，清除系统代理
      if (!singboxRunning && proxySet) {
        await SystemProxyHelper.clearProxy();
      }
    });
  }
}
```

## ⚠️ 注意事项

### 1. Windows 权限
- 设置系统代理需要修改注册表
- 通常不需要管理员权限
- 但某些安全软件可能会拦截

### 2. 代理设置范围
- 当前设置的是 Internet Explorer 代理
- Windows 系统和大多数应用会使用这个代理
- 部分应用（如 Chrome）可能有独立的代理设置

### 3. 异常处理
```dart
try {
  bool success = await SystemProxyHelper.setProxy('127.0.0.1', 15808);
  if (!success) {
    // 设置失败，显示提示
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('代理设置失败'),
        content: Text('无法设置系统代理，请检查权限或手动设置'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
} catch (e) {
  print('设置代理异常: $e');
}
```

### 4. 本地地址不走代理
系统代理自动添加了 `ProxyOverride = "<local>"`，这意味着：
- `localhost` 不走代理
- `127.0.0.1` 不走代理
- 局域网地址不走代理

## 🧪 测试

### 手动测试步骤

1. **启动应用**
   - 确认 sing-box 未运行
   - 确认系统代理未设置

2. **点击连接**
   - sing-box 启动成功
   - 系统代理设置为 `127.0.0.1:15808`
   - 浏览器可以访问外网

3. **检查系统代理**
   ```
   Windows 设置 → 网络和Internet → 代理
   应该看到:
   - 使用代理服务器: 开启
   - 地址: 127.0.0.1:15808
   ```

4. **点击断开**
   - sing-box 停止
   - 系统代理清除
   - 浏览器恢复直连

### 代码测试

```dart
void testSystemProxy() async {
  // 测试设置代理
  print('测试设置代理...');
  bool result1 = await SystemProxyHelper.setProxy('127.0.0.1', 15808);
  print('设置结果: $result1');
  
  // 检查状态
  ProxyStatus status1 = await SystemProxyHelper.getProxyStatus();
  print('代理状态: $status1');
  
  // 测试清除代理
  print('\\n测试清除代理...');
  bool result2 = await SystemProxyHelper.clearProxy();
  print('清除结果: $result2');
  
  // 检查状态
  ProxyStatus status2 = await SystemProxyHelper.getProxyStatus();
  print('代理状态: $status2');
}
```

## 📚 参考资料

- [Windows Internet Settings Registry](https://learn.microsoft.com/en-us/windows/win32/wininet/internet-settings)
- [Win32 Registry Functions](https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-functions)
- [Flutter FFI Documentation](https://dart.dev/guides/libraries/c-interop)

