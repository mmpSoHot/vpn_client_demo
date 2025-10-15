# Android VPN 实现研究（基于 sing-box-for-android）

## 核心架构

### 关键组件

1. **VPNService** - Android VPN 服务
2. **BoxService** - sing-box 核心服务
3. **TunOptions** - TUN 接口配置
4. **PlatformInterfaceWrapper** - 平台接口

## VPN 实现原理

### Android VPN API

Android 提供了官方的 `VpnService` API：

```kotlin
class VPNService : VpnService(), PlatformInterfaceWrapper {
    
    override fun openTun(options: TunOptions): Int {
        // 1. 检查 VPN 权限
        if (prepare(this) != null) error("missing vpn permission")
        
        // 2. 创建 VPN Builder
        val builder = Builder()
            .setSession("sing-box")
            .setMtu(options.mtu)
        
        // 3. 配置 IP 地址
        builder.addAddress(address, prefix)
        
        // 4. 配置路由
        builder.addRoute("0.0.0.0", 0)  // 全局路由
        
        // 5. 配置 DNS
        builder.addDnsServer(dnsServerAddress)
        
        // 6. 配置应用代理（可选）
        builder.addAllowedApplication(packageName)
        // 或
        builder.addDisallowedApplication(packageName)
        
        // 7. 建立 VPN 连接
        val pfd = builder.establish()
        return pfd.fd  // 返回文件描述符给 sing-box
    }
}
```

### 工作流程

```
用户点击连接
  ↓
请求 VPN 权限 (VpnService.prepare())
  ↓
用户授权
  ↓
创建 VPN Builder
  ↓
配置 IP、路由、DNS
  ↓
建立 VPN 连接 (builder.establish())
  ↓
获取 TUN 文件描述符
  ↓
传递给 sing-box 核心
  ↓
sing-box 通过 TUN 接口处理所有流量
```

## 必需权限

### AndroidManifest.xml

```xml
<!-- VPN 相关 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />

<!-- 开机启动 -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- 网络状态 -->
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />

<!-- 省电优化豁免 -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

<!-- 分应用代理需要 -->
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
```

### Service 声明

```xml
<service
    android:name=".bg.VPNService"
    android:exported="false"
    android:foregroundServiceType="systemExempted"
    android:permission="android.permission.BIND_VPN_SERVICE">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```

## 关键功能

### 1. TUN 接口配置

```kotlin
val builder = Builder()
    .setSession("sing-box")
    .setMtu(options.mtu)  // MTU: 通常 1500
    
// IPv4 地址
builder.addAddress("172.19.0.1", 30)

// IPv6 地址（可选）
builder.addAddress("fdfe:dcba:9876::1", 126)
```

### 2. 路由配置

```kotlin
// 全局代理：所有流量
builder.addRoute("0.0.0.0", 0)
builder.addRoute("::", 0)

// 排除路由（绕过某些地址）
builder.excludeRoute("192.168.0.0", 16)
builder.excludeRoute("10.0.0.0", 8)
```

### 3. DNS 配置

```kotlin
builder.addDnsServer("8.8.8.8")
builder.addDnsServer("2001:4860:4860::8888")
```

### 4. 分应用代理

```kotlin
// 仅代理指定应用
builder.addAllowedApplication("com.android.chrome")
builder.addAllowedApplication("com.google.android.youtube")

// 或排除某些应用
builder.addDisallowedApplication("com.tencent.mm")  // 微信直连
```

### 5. HTTP 代理（Android 10+）

```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
    builder.setHttpProxy(
        ProxyInfo.buildDirectProxy(
            "127.0.0.1",
            1080,
            listOf("localhost", "127.*", "10.*")
        )
    )
}
```

### 6. 保护连接

```kotlin
override fun autoDetectInterfaceControl(fd: Int) {
    protect(fd)  // 保护 sing-box 的连接不被 VPN 路由
}
```

## 与 Windows 的区别

| 特性 | Windows | Android |
|------|---------|---------|
| 代理方式 | 系统代理 (Registry) | VPN TUN 接口 |
| 需要权限 | 管理员 | VPN 权限（用户授权） |
| 流量劫持 | 应用层代理 | 网络层 TUN |
| 实现复杂度 | 简单 | 中等 |
| 应用覆盖 | 仅支持代理的应用 | 所有应用（可选择） |
| 系统集成 | 较弱 | 很强 |

## 实现 Android 版本需要做什么

### 1. 添加 Android VPN 权限

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />
```

### 2. 创建 VPNService

```kotlin
// android/app/src/main/kotlin/.../VPNService.kt
class VPNService : VpnService() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 启动 VPN
        val builder = Builder()
            .setSession("VPN Client Demo")
            .setMtu(1500)
            .addAddress("172.19.0.1", 30)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("8.8.8.8")
        
        val pfd = builder.establish()
        // 将文件描述符传递给 sing-box
        
        return START_STICKY
    }
}
```

### 3. 注册 Service

```xml
<service
    android:name=".VPNService"
    android:exported="false"
    android:permission="android.permission.BIND_VPN_SERVICE">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```

### 4. Flutter 端启动 VPN

```dart
// lib/utils/android_vpn_helper.dart
class AndroidVpnHelper {
  static const MethodChannel _channel = MethodChannel('vpn_service');
  
  static Future<bool> startVpn() async {
    try {
      final result = await _channel.invokeMethod('startVpn');
      return result == true;
    } catch (e) {
      print('启动 VPN 失败: $e');
      return false;
    }
  }
  
  static Future<bool> stopVpn() async {
    try {
      final result = await _channel.invokeMethod('stopVpn');
      return result == true;
    } catch (e) {
      print('停止 VPN 失败: $e');
      return false;
    }
  }
}
```

### 5. Kotlin 端实现 MethodChannel

```kotlin
// MainActivity.kt
class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vpn_service")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startVpn" -> {
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            // 需要权限
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                            result.success(false)
                        } else {
                            // 已有权限，启动 VPN
                            startService(Intent(this, VPNService::class.java))
                            result.success(true)
                        }
                    }
                    "stopVpn" -> {
                        stopService(Intent(this, VPNService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

## sing-box TUN 配置（Android）

```json
{
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "inet4_address": "172.19.0.1/30",
      "inet6_address": "fdfe:dcba:9876::1/126",
      "mtu": 1500,
      "auto_route": true,
      "strict_route": true,
      "stack": "gvisor",
      "sniff": true,
      "sniff_override_destination": true
    }
  ]
}
```

## 关键 API

### VpnService.Builder 常用方法

| 方法 | 说明 | 示例 |
|------|------|------|
| `setSession()` | 设置会话名称 | `.setSession("VPN Demo")` |
| `setMtu()` | 设置 MTU | `.setMtu(1500)` |
| `addAddress()` | 添加 IP 地址 | `.addAddress("172.19.0.1", 30)` |
| `addRoute()` | 添加路由 | `.addRoute("0.0.0.0", 0)` |
| `excludeRoute()` | 排除路由 | `.excludeRoute("192.168.0.0", 16)` |
| `addDnsServer()` | 添加 DNS | `.addDnsServer("8.8.8.8")` |
| `addAllowedApplication()` | 允许应用 | `.addAllowedApplication("com.app")` |
| `addDisallowedApplication()` | 排除应用 | `.addDisallowedApplication("com.app")` |
| `setHttpProxy()` | 设置 HTTP 代理 | `.setHttpProxy(ProxyInfo...)` |
| `establish()` | 建立连接 | `.establish()` 返回 ParcelFileDescriptor |

### 文件描述符传递

```kotlin
val pfd = builder.establish()
val fd = pfd.fd  // 获取文件描述符

// 传递给 sing-box（通过 JNI/FFI）
SingBoxCore.startWithFd(fd, configPath)
```

## 前台服务通知

Android 要求 VPN 服务必须显示通知：

```kotlin
class VPNService : VpnService() {
    override fun onStartCommand(...): Int {
        // 创建通知渠道
        val channel = NotificationChannel(
            "vpn_channel",
            "VPN Service",
            NotificationManager.IMPORTANCE_LOW
        )
        
        // 显示前台服务通知
        val notification = Notification.Builder(this, "vpn_channel")
            .setContentTitle("VPN 已连接")
            .setContentText("流量正在通过 VPN")
            .setSmallIcon(R.drawable.ic_vpn)
            .build()
        
        startForeground(1, notification)
        
        return START_STICKY
    }
}
```

## 优势与挑战

### Android VPN 的优势

✅ **全局流量劫持**：
- 所有应用的流量都经过 VPN
- 不需要单独配置代理

✅ **系统级集成**：
- 系统状态栏显示 VPN 图标
- 快捷设置磁贴
- 自动断开重连

✅ **应用级控制**：
- 可选择哪些应用走 VPN
- 可排除某些应用（如银行应用）

### 实现挑战

❌ **复杂度高**：
- 需要编写 Kotlin/Java 代码
- 需要理解 Android VPN API
- 需要处理权限请求

❌ **平台特定**：
- 仅限 Android
- 需要单独维护

❌ **sing-box 集成**：
- 需要将 sing-box 编译为 .so 库
- 需要通过 JNI/FFI 调用
- 需要处理文件描述符传递

## sing-box-for-android 的方案

### libbox 库

sing-box 提供了 `libbox` 库：
- Go 语言编译为 Android .so
- 提供 Java/Kotlin 绑定
- 封装了 TUN 接口管理

### 文件结构

```
libbox/
├── libbox.aar          # Android 库
├── Libbox.kt           # Kotlin 接口
└── jni/
    └── libbox.so       # Go 编译的动态库
```

### 使用方式

```kotlin
import io.nekohasekai.libbox.*

// 创建 sing-box 实例
val box = BoxService(context)

// 启动 sing-box
box.start(configPath, tunFd)

// 停止 sing-box
box.stop()
```

## 对我们项目的建议

### 阶段 1：Windows 优先（当前）

✅ **专注 Windows 平台**：
- 使用系统代理（已实现）
- 简单可靠
- 快速上线

### 阶段 2：考虑 Android

如果要支持 Android，有两个方案：

**方案 A：使用 HTTP 代理（简单）**
```dart
// 不使用 VPN，使用 HTTP 代理
// 用户需要手动在 Android WiFi 设置中配置代理
// 或使用第三方代理工具（如 Postern）
```

**方案 B：实现完整 VPN（复杂）**
```kotlin
// 1. 添加 VPNService
// 2. 集成 libbox.aar
// 3. 实现 TUN 接口
// 4. 处理权限和通知
```

### 推荐方案

**短期**：专注 Windows
- ✅ 已完成系统代理
- ✅ 功能完整
- ✅ 用户体验好

**长期**：参考 karing
- karing 已经实现了 Android VPN
- 可以学习它的实现方式
- 代码更接近我们的架构（都是 Flutter + sing-box）

## karing 的 Android 实现

让我查看 karing 的 Android 实现（它也在参考项目中）：

```
参考项目/karing/android/
```

karing 使用了：
1. **VPN Service** - Android VPN
2. **libbox** - sing-box 核心库
3. **Flutter MethodChannel** - Dart 与 Kotlin 通信

## 总结

### sing-box-for-android 的核心要点

1. **VpnService API**：Android 官方 VPN 接口
2. **TUN 接口**：网络层流量劫持
3. **libbox 库**：sing-box 的 Android 绑定
4. **前台服务**：必须显示通知
5. **权限管理**：VPN 权限需要用户授权

### 对我们的启示

✅ **Windows 平台已经做得很好**：
- 系统代理设置
- sing-box.exe 集成
- 路径管理规范

🔮 **Android 实现可以参考**：
- sing-box-for-android 的官方实现
- karing 的 Flutter 集成方式
- FlClash 的 UI 设计

**建议**：先把 Windows 版本完善，Android 版本可以作为后续计划。

## 相关资源

- [Android VpnService 官方文档](https://developer.android.com/reference/android/net/VpnService)
- [sing-box-for-android 源码](https://github.com/SagerNet/sing-box-for-android)
- [libbox 文档](https://sing-box.sagernet.org/clients/android/)

