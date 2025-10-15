# Karing Android VPN 实现研究

## 核心架构

Karing 使用了一个自定义的 Flutter 插件 `vpn_service` 来处理 Android VPN：

```dart
import 'package:vpn_service/vpn_service.dart';
import 'package:vpn_service/state.dart';
```

## VPN 状态管理

### 状态枚举

```dart
enum FlutterVpnServiceState {
  invalid,        // 无效状态
  disconnected,   // 已断开
  connected,      // 已连接
}
```

### 使用方式

```dart
// 获取 VPN 启动状态
bool started = await VPNService.getStarted();

// 设置 Always-On VPN
await FlutterVpnService.setAlwaysOn(true);

// 获取系统版本
String version = await FlutterVpnService.getSystemVersion();

// 获取进程列表（macOS）
String? plist = await FlutterVpnService.getProcessList();

// 获取进程图标
Uint8List? data = await FlutterVpnService.getProcessIcon(identifier);
```

## 权限配置

### AndroidManifest.xml

karing 所需的权限：

```xml
<!-- 基本权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />

<!-- 通知 -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- 开机启动 -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- 网络状态 -->
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- 省电优化豁免 -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

<!-- 分应用代理 -->
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"/>
```

## vpn_service 插件

### 插件结构

虽然我们没有 `vpn_service` 的源码，但从使用方式可以推断它提供：

1. **VPN 连接管理**：
   ```dart
   class VPNService {
     static Future<bool> getStarted();
     static Future<bool> start(config);
     static Future<bool> stop();
   }
   ```

2. **状态监听**：
   ```dart
   class FlutterVpnService {
     static Stream<FlutterVpnServiceState> get stateStream;
     static FlutterVpnServiceState get currentState;
   }
   ```

3. **平台特定功能**：
   ```dart
   // Android
   static Future<void> setAlwaysOn(bool enabled);
   
   // macOS
   static Future<String?> getProcessList();
   static Future<Uint8List?> getProcessIcon(String identifier);
   ```

## karing 的 VPN 启动流程

从代码中可以看出：

```dart
// 1. 检查 VPN 状态
bool started = await VPNService.getStarted();

// 2. 生成配置
String config = await generateSingboxConfig();

// 3. 启动 VPN
if (state == FlutterVpnServiceState.disconnected) {
  await start("launch");
}

// 4. 监听状态变化
FlutterVpnService.stateStream.listen((state) {
  if (state == FlutterVpnServiceState.connected) {
    // 连接成功
  }
});
```

## 对我们项目的启示

### 当前我们的 Windows 实现

```dart
// lib/utils/singbox_manager.dart
class SingboxManager {
  static Future<bool> start() {
    // 启动 sing-box 进程
  }
  
  static Future<bool> stop() {
    // 停止 sing-box 进程
  }
}
```

### Android 实现需要

**方案 A：使用现成的 VPN 插件**

寻找或使用类似的 Flutter VPN 插件：
- `flutter_vpn` (已不维护)
- `openvpn_flutter`
- 或自己创建一个简单的插件

**方案 B：参考 sing-box-for-android**

创建自己的 VPN 插件：

```
lib/
└── plugins/
    └── vpn_service/
        ├── android/
        │   └── src/main/kotlin/
        │       └── VPNService.kt
        ├── lib/
        │   └── vpn_service.dart
        └── pubspec.yaml
```

## 推荐实现路径

### 阶段 1：Windows 完善（当前）✅

- ✅ 系统代理实现
- ✅ sing-box 集成
- ✅ 全局/绕过大陆模式
- ✅ 实时网速监控
- ✅ 打包方案

### 阶段 2：Android 基础

**简化方案**（快速上线）：
```dart
// 不实现 VPN，使用 HTTP 代理
// 提供订阅链接，让用户在其他 VPN 应用中导入
// 如：Clash for Android, v2rayNG
```

### 阶段 3：Android VPN（完整）

**完整实现**：
1. 创建 `vpn_service` 插件
2. 实现 Android VPNService
3. 集成 libbox（sing-box Android 库）
4. 实现 TUN 接口
5. 权限管理
6. 前台服务通知

## 创建简单的 VPN 插件（最小实现）

### 插件结构

```
lib/plugins/vpn_service/
├── android/
│   ├── build.gradle
│   └── src/main/kotlin/
│       └── VpnServicePlugin.kt
├── lib/
│   └── vpn_service.dart
└── pubspec.yaml
```

### Android 端（Kotlin）

```kotlin
// VpnServicePlugin.kt
class VpnServicePlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    
    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "vpn_service")
        channel?.setMethodCallHandler(this)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "start" -> {
                // 启动 VPN
                result.success(true)
            }
            "stop" -> {
                // 停止 VPN
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
```

### Flutter 端（Dart）

```dart
// vpn_service.dart
class VpnService {
  static const MethodChannel _channel = MethodChannel('vpn_service');
  
  static Future<bool> start(String config) async {
    try {
      final result = await _channel.invokeMethod('start', {'config': config});
      return result == true;
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod('stop');
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
```

## 总结

### karing 的方案

✅ **优点**：
- 使用 Flutter 插件封装 VPN 逻辑
- 跨平台统一 API
- 代码组织清晰

❌ **缺点**：
- 需要单独的 `vpn_service` 插件
- 插件不在 pub.dev，需要自己维护

### 我们的选择

**短期（推荐）**：
- 专注 Windows 平台 ✅
- 功能已完整
- 可以快速上线

**中期**：
- 提供订阅链接
- 用户可在其他 Android VPN 应用中导入

**长期**：
- 参考 sing-box-for-android 实现完整 VPN
- 或创建简化的 VPN 插件

**结论**：Windows 版本已经做得很好，Android 可以作为后续扩展！

## 相关资源

- `参考项目/karing/android/` - karing Android 实现
- `参考项目/sing-box-for-android/` - sing-box 官方 Android 客户端
- Flutter VPN 插件示例

