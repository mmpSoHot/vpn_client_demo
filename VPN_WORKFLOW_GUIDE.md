# VPN 客户端工作流程指南

## 📋 Karing 的实现方式总结

根据对 karing 项目的分析，VPN 客户端的工作流程如下：

### 🔄 核心工作流程

#### 1. **应用启动时**
```dart
// 应用启动时
void initState() {
  super.initState();
  // 不自动启动 sing-box，只初始化配置
  loadConfig();
}
```

#### 2. **用户点击"连接"按钮时**
```dart
Future<void> onConnect() async {
  // Step 1: 生成 sing-box 配置
  var result = await buildSingboxConfig(node);
  
  // Step 2: 启动 sing-box 核心
  var err = await VPNService.start(timeout);
  
  // Step 3: (可选) 设置系统代理
  if (autoSetProxy) {
    await VPNService.setSystemProxy(true);
  }
  
  // Step 4: 启动其他服务（如 ProxyCluster）
  if (enableCluster) {
    await ProxyCluster.start();
  }
}
```

#### 3. **用户点击"断开"按钮时**
```dart
Future<void> onDisconnect() async {
  // Step 1: 停止 sing-box 核心
  await VPNService.stop();
  
  // Step 2: 清除系统代理
  await VPNService.setSystemProxy(false);
  
  // Step 3: 停止其他服务
  await ProxyCluster.stop();
}
```

### 🎛️ 系统代理开关（独立控制）

karing 还提供了**独立的系统代理开关**，与 VPN 连接分离：

```dart
// SystemProxyCard - 独立的系统代理开关
class SystemProxyCard extends SwitchCard {
  SystemProxyCard({
    super.key,
    super.onAfterPressed,
    this.onValueChanged,
  }) : super(
    icon: Icons.phonelink,
    title: t.SystemProxy,
    getEnable: VPNService.getSystemProxyEnable,
    onChanged: (context, value) async {
      // 只设置/清除系统代理，不影响 sing-box 运行
      await VPNService.setSystemProxy(value);
      
      // 获取实际设置结果
      final newValue = await VPNService.getSystemProxyEnable();
      if (value != newValue) {
        onValueChanged?.call(value);
      }
    }
  );
}
```

## 🎯 推荐的实现方案

### 方案 A：简单模式（推荐用于你的项目）

```dart
// 1. 首页的连接/断开开关
class HomePage extends StatefulWidget {
  bool isConnected = false;
  
  Future<void> onToggleConnection(bool value) async {
    if (value) {
      // 连接
      await _connect();
    } else {
      // 断开
      await _disconnect();
    }
  }
  
  Future<void> _connect() async {
    // Step 1: 生成配置
    await SingboxManager.generateConfigFromNode(
      node: selectedNode,
      mixedPort: 15808,
    );
    
    // Step 2: 启动 sing-box
    bool success = await SingboxManager.start();
    
    // Step 3: 自动设置系统代理
    if (success) {
      await setSystemProxy(true, '127.0.0.1', 15808);
      setState(() => isConnected = true);
    }
  }
  
  Future<void> _disconnect() async {
    // Step 1: 清除系统代理
    await clearSystemProxy();
    
    // Step 2: 停止 sing-box
    await SingboxManager.stop();
    
    setState(() => isConnected = false);
  }
}
```

### 方案 B：高级模式（类似 karing）

如果你想要更灵活的控制：

```dart
// 1. VPN 连接开关（控制 sing-box 启动/停止）
class VPNSwitch {
  Future<void> toggle(bool enable) async {
    if (enable) {
      await SingboxManager.generateConfigFromNode(...);
      await SingboxManager.start();
    } else {
      await SingboxManager.stop();
    }
  }
}

// 2. 系统代理开关（独立控制，sing-box 可以运行但不设置系统代理）
class SystemProxySwitch {
  Future<void> toggle(bool enable) async {
    if (enable) {
      await setSystemProxy(true, '127.0.0.1', 15808);
    } else {
      await clearSystemProxy();
    }
  }
}
```

## 🔧 实现建议

### 1. **生命周期管理**

```dart
@override
void initState() {
  super.initState();
  
  // ❌ 不要在应用启动时自动启动 sing-box
  // await SingboxManager.start();
  
  // ✅ 只检查上次的连接状态
  _checkLastConnectionState();
}

@override
void dispose() {
  // 应用关闭时，保持 sing-box 运行（可选）
  // 或者停止 sing-box
  super.dispose();
}
```

### 2. **系统代理管理**

Windows 系统代理设置需要调用系统 API：

```dart
import 'dart:ffi';
import 'package:win32/win32.dart';

Future<void> setSystemProxy(bool enable, String host, int port) async {
  if (Platform.isWindows) {
    // 使用 win32 API 设置代理
    final proxyServer = enable ? '$host:$port' : '';
    
    // 设置注册表
    // HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings
    
    // 通知系统代理设置已更改
    InternetSetOption(
      null,
      INTERNET_OPTION_SETTINGS_CHANGED,
      null,
      0,
    );
  }
}
```

### 3. **状态同步**

```dart
class ConnectionState {
  bool isSingboxRunning = false;    // sing-box 运行状态
  bool isSystemProxySet = false;    // 系统代理设置状态
  
  // 定时检查状态
  Timer? _stateChecker;
  
  void startStateChecker() {
    _stateChecker = Timer.periodic(Duration(seconds: 3), (timer) {
      isSingboxRunning = SingboxManager.isRunning();
      isSystemProxySet = await getSystemProxyState();
      setState(() {});
    });
  }
}
```

## 📊 工作流程对比

### Karing 的方式（高级）
```
应用启动 → 不启动核心
用户点击连接 → 启动 sing-box → (可选)设置系统代理
用户切换系统代理开关 → 仅设置/清除代理（不影响 sing-box）
用户点击断开 → 停止 sing-box + 清除代理
```

### 推荐给你的方式（简单）
```
应用启动 → 不启动核心
用户点击连接 → 启动 sing-box + 自动设置系统代理
用户点击断开 → 停止 sing-box + 清除系统代理
```

## 🎨 UI 实现示例

```dart
// 首页连接开关
SwitchListTile(
  title: Text('VPN 连接'),
  subtitle: Text(isConnected ? '已连接' : '未连接'),
  value: isConnected,
  onChanged: (value) async {
    if (value) {
      // 连接
      await SingboxManager.generateConfigFromNode(
        node: selectedNode,
        mixedPort: 15808,
      );
      bool started = await SingboxManager.start();
      
      if (started) {
        await setSystemProxy(true, '127.0.0.1', 15808);
        setState(() => isConnected = true);
        showSnackBar('VPN 已连接');
      }
    } else {
      // 断开
      await clearSystemProxy();
      await SingboxManager.stop();
      setState(() => isConnected = false);
      showSnackBar('VPN 已断开');
    }
  },
)
```

## ⚠️ 重要注意事项

1. **不要在应用启动时自动启动 sing-box**
   - 让用户主动点击连接按钮

2. **一键连接应该包括**：
   - 生成配置 → 启动 sing-box → 设置系统代理

3. **一键断开应该包括**：
   - 清除系统代理 → 停止 sing-box

4. **状态监控**：
   - 定期检查 sing-box 是否还在运行
   - 检查系统代理是否被其他程序修改

5. **错误处理**：
   - sing-box 启动失败时，不要设置系统代理
   - 显示友好的错误提示

## 📝 下一步实现

1. 创建系统代理管理工具类
2. 修改首页连接开关逻辑
3. 添加状态监控和同步
4. 完善错误处理和用户提示

