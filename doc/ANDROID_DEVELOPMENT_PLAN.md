# Android 版本开发计划

## 项目目标

在当前 Flutter 项目基础上添加 Android VPN 功能，复用现有的：
- ✅ 配置生成逻辑 (`node_config_converter.dart`)
- ✅ 节点管理 (`node_model.dart`, `api_service.dart`)
- ✅ UI 界面（所有页面）
- ✅ 代理模式逻辑

## 开发路线图

### 阶段 1：准备工作 (1 天)

#### 1.1 开发环境

**必需工具**：
- ✅ Flutter SDK (已有)
- ✅ Android Studio
- ✅ Android SDK (API 21+)
- ✅ Android NDK
- ⚠️ Go 1.21+ (用于编译 libbox)
- ⚠️ gomobile

**安装 Go 和 gomobile**：
```bash
# 1. 安装 Go
# 下载：https://go.dev/dl/

# 2. 安装 gomobile
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

# 3. 验证
gomobile version
```

#### 1.2 获取 libbox.aar

**方案 A - 从现有项目提取（推荐，快速）**：
```bash
# 从 NekoBox 或 sing-box-for-android 提取
cp 参考项目/NekoBoxForAndroid-main/app/libs/libcore.aar android/app/libs/

# 重命名
mv android/app/libs/libcore.aar android/app/libs/libbox.aar
```

**方案 B - 自己编译（高级）**：
```bash
# 克隆 sing-box
git clone https://github.com/SagerNet/sing-box.git
cd sing-box

# 编译 Android 库
make lib_android

# 输出：experimental/libbox/libbox.aar
```

### 阶段 2：创建 VPN 服务 (2-3 天)

#### 2.1 创建文件结构

```
android/app/src/main/
├── kotlin/com/example/demo2/
│   ├── VpnService.kt           # VPN 服务
│   ├── PlatformInterfaceImpl.kt  # 平台接口实现
│   ├── VpnHelper.kt            # VPN 辅助类
│   └── MainActivity.kt         # 主活动（已有，需修改）
└── AndroidManifest.xml         # 需要添加权限和服务
```

#### 2.2 修改 AndroidManifest.xml

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
    <!-- 添加权限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <application>
        <!-- 添加 VPN 服务 -->
        <service
            android:name=".VpnService"
            android:exported="false"
            android:foregroundServiceType="specialUse"
            android:permission="android.permission.BIND_VPN_SERVICE">
            <intent-filter>
                <action android:name="android.net.VpnService" />
            </intent-filter>
        </service>
    </application>
</manifest>
```

#### 2.3 创建 VpnService.kt

```kotlin
package com.example.demo2

import android.net.VpnService as AndroidVpnService
import android.content.Intent
import android.os.IBinder
import libbox.Libbox
import libbox.BoxService
import libbox.PlatformInterface
import libbox.TunOptions

class VpnService : AndroidVpnService() {
    
    private var boxInstance: BoxService? = null
    
    companion object {
        const val ACTION_START = "com.example.demo2.START"
        const val ACTION_STOP = "com.example.demo2.STOP"
        const val EXTRA_CONFIG = "config"
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
                startVpn(config)
            }
            ACTION_STOP -> {
                stopVpn()
            }
        }
        return START_STICKY
    }
    
    private fun startVpn(configJson: String) {
        try {
            // 创建平台接口
            val platformInterface = PlatformInterfaceImpl(this)
            
            // 创建 sing-box 实例
            boxInstance = Libbox.newService(configJson, platformInterface)
            
            // 启动
            boxInstance?.start()
            
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }
    
    private fun stopVpn() {
        boxInstance?.close()
        boxInstance = null
        stopSelf()
    }
    
    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
```

#### 2.4 创建 PlatformInterfaceImpl.kt

```kotlin
package com.example.demo2

import android.net.VpnService
import android.util.Log
import libbox.PlatformInterface
import libbox.TunOptions
import libbox.Notification

class PlatformInterfaceImpl(
    private val vpnService: VpnService
) : PlatformInterface {
    
    override fun autoDetectInterfaceControl(fd: Long) {
        vpnService.protect(fd.toInt())
    }
    
    override fun openTun(options: TunOptions): Long {
        val builder = VpnService.Builder()
            .setSession("VPN Client Demo")
            .setMtu(options.mtu.toInt())
        
        // 添加 IPv4 地址
        val inet4Address = options.inet4Address
        while (inet4Address.hasNext()) {
            val addr = inet4Address.next()
            builder.addAddress(addr.address(), addr.prefix().toInt())
        }
        
        // 添加路由
        if (options.autoRoute) {
            builder.addRoute("0.0.0.0", 0)
            builder.addDnsServer(options.dnsServerAddress)
        }
        
        // 建立 VPN 连接
        val pfd = builder.establish() 
            ?: throw Exception("Failed to establish VPN")
        
        return pfd.fd.toLong()
    }
    
    override fun writeLog(message: String) {
        Log.d("sing-box", message)
    }
    
    override fun sendNotification(notification: Notification) {
        // TODO: 实现通知功能
    }
}
```

### 阶段 3：Flutter 桥接 (1 天)

#### 3.1 创建 Android VPN Helper

```dart
// lib/utils/android_vpn_helper.dart
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/node_model.dart';
import 'node_config_converter.dart';
import 'dart:convert';

class AndroidVpnHelper {
  static const MethodChannel _channel = MethodChannel('vpn_service');
  
  /// 启动 VPN
  static Future<bool> startVpn({
    required NodeModel node,
    ProxyMode proxyMode = ProxyMode.bypassCN,
  }) async {
    if (!Platform.isAndroid) return false;
    
    try {
      // 生成配置
      final config = NodeConfigConverter.generateFullConfig(
        node: node,
        mixedPort: 15808,
        enableTun: true,  // Android 使用 TUN 模式
        enableStatsApi: true,
        proxyMode: proxyMode,
      );
      
      // 调用 Android
      final result = await _channel.invokeMethod('startVpn', {
        'config': jsonEncode(config),
      });
      
      return result == true;
    } catch (e) {
      print('启动 Android VPN 失败: $e');
      return false;
    }
  }
  
  /// 停止 VPN
  static Future<bool> stopVpn() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('stopVpn');
      return result == true;
    } catch (e) {
      print('停止 Android VPN 失败: $e');
      return false;
    }
  }
  
  /// 检查 VPN 权限
  static Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod('checkPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }
  
  /// 请求 VPN 权限
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod('requestPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
```

#### 3.2 修改 MainActivity.kt

```kotlin
// android/app/src/main/kotlin/com/example/demo2/MainActivity.kt
package com.example.demo2

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VPN_REQUEST_CODE = 100
    private var pendingResult: MethodChannel.Result? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vpn_service")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermission" -> {
                        val intent = VpnService.prepare(this)
                        result.success(intent == null)
                    }
                    
                    "requestPermission" -> {
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            pendingResult = result
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                        } else {
                            result.success(true)
                        }
                    }
                    
                    "startVpn" -> {
                        val config = call.argument<String>("config")
                        if (config != null) {
                            val intent = Intent(this, VpnService::class.java).apply {
                                action = VpnService.ACTION_START
                                putExtra(VpnService.EXTRA_CONFIG, config)
                            }
                            startService(intent)
                            result.success(true)
                        } else {
                            result.error("INVALID_CONFIG", "配置为空", null)
                        }
                    }
                    
                    "stopVpn" -> {
                        val intent = Intent(this, VpnService::class.java).apply {
                            action = VpnService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    
                    else -> result.notImplemented()
                }
            }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VPN_REQUEST_CODE) {
            pendingResult?.success(resultCode == RESULT_OK)
            pendingResult = null
        }
    }
}
```

### 阶段 4：修改 Flutter 代码 (1 天)

#### 4.1 修改 home_page.dart 连接逻辑

```dart
// lib/pages/home_page.dart

Future<void> _connectVPN() async {
  if (_selectedNodeModel == null) {
    _showError('请先选择节点');
    return;
  }
  
  setState(() {
    _isConnecting = true;
    _connectionStatus = '连接中...';
  });
  
  try {
    bool success = false;
    
    if (Platform.isWindows) {
      // Windows 实现（已有）
      await SingboxManager.generateConfigFromNode(
        node: _selectedNodeModel!,
        mixedPort: 15808,
        proxyMode: _proxyMode,
      );
      
      bool started = await SingboxManager.start();
      if (started) {
        await SystemProxyHelper.setProxy('127.0.0.1', 15808);
        success = true;
      }
    } else if (Platform.isAndroid) {
      // Android 实现（新增）
      // 1. 检查权限
      bool hasPermission = await AndroidVpnHelper.checkPermission();
      if (!hasPermission) {
        hasPermission = await AndroidVpnHelper.requestPermission();
        if (!hasPermission) {
          _showError('需要 VPN 权限才能使用');
          return;
        }
      }
      
      // 2. 启动 VPN
      success = await AndroidVpnHelper.startVpn(
        node: _selectedNodeModel!,
        proxyMode: _proxyMode,
      );
    }
    
    if (success) {
      setState(() {
        _connectionStatus = '已连接';
        _isConnecting = false;
      });
      widget.onConnectionStateChanged(true);
      _showSuccess('VPN 连接成功');
      
      // 启动网速监控
      Future.delayed(const Duration(seconds: 2), () {
        _speedService.startMonitoring();
      });
    } else {
      throw Exception('启动失败');
    }
  } catch (e) {
    _showError('连接失败: $e');
    setState(() {
      _isConnecting = false;
      _connectionStatus = '未连接';
    });
  }
}

Future<void> _disconnectVPN() async {
  setState(() {
    _isConnecting = true;
    _connectionStatus = '断开中...';
  });
  
  try {
    if (Platform.isWindows) {
      // Windows 断开（已有）
      await SystemProxyHelper.clearProxy();
      await SingboxManager.stop();
    } else if (Platform.isAndroid) {
      // Android 断开（新增）
      await AndroidVpnHelper.stopVpn();
    }
    
    _speedService.stopMonitoring();
    
    setState(() {
      _connectionStatus = '未连接';
      _isConnecting = false;
    });
    widget.onConnectionStateChanged(false);
    _showSuccess('VPN 已断开');
  } catch (e) {
    _showError('断开失败: $e');
  }
}
```

#### 4.2 修改 node_config_converter.dart

添加 TUN 配置生成：

```dart
// lib/utils/node_config_converter.dart

/// 获取 TUN 入站配置（Android/iOS）
static List<Map<String, dynamic>> _getTunInbounds() {
  return [
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
  ];
}

// 在 generateFullConfig 中使用
"inbounds": enableTun ? _getTunInbounds() : _getMixedInbounds(mixedPort),
```

### 阶段 5：添加依赖和配置 (0.5 天)

#### 5.1 修改 android/app/build.gradle

```gradle
android {
    // ...
    
    defaultConfig {
        minSdkVersion 21  // 最低 Android 5.0
        targetSdkVersion 34
        // ...
    }
}

dependencies {
    // 添加 libbox
    implementation(fileTree(dir: "libs", include: ["*.aar"]))
    
    // 其他依赖
    implementation "androidx.core:core-ktx:1.12.0"
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
}
```

#### 5.2 创建 libs 目录

```bash
mkdir -p android/app/libs
# 将 libbox.aar 放入此目录
```

### 阶段 6：UI 适配 (1 天)

#### 6.1 添加平台判断

```dart
// lib/pages/home_page.dart

Widget build(BuildContext context) {
  return Column(
    children: [
      // 连接状态卡片
      _buildStatusCard(),
      
      // 节点选择
      _buildNodeSelector(),
      
      // 功能区块（出站模式 + 流量统计）
      _buildFunctionsSection(),
      
      // Android 特有：显示 VPN 状态
      if (Platform.isAndroid) _buildAndroidVpnStatus(),
      
      // 订阅信息
      if (_subscribeInfo != null) _buildSubscribeCard(),
    ],
  );
}

Widget _buildAndroidVpnStatus() {
  return Container(
    padding: EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(Icons.vpn_key, color: Color(0xFF007AFF)),
        SizedBox(width: 8),
        Text('VPN 模式：TUN 接口'),
      ],
    ),
  );
}
```

### 阶段 7：测试和调试 (2-3 天)

#### 7.1 测试清单

- [ ] VPN 权限请求
- [ ] VPN 连接/断开
- [ ] 全局代理模式
- [ ] 绕过大陆模式
- [ ] 节点切换
- [ ] 实时网速显示
- [ ] 应用生命周期管理
- [ ] 系统通知
- [ ] 开机自启动（可选）

#### 7.2 调试工具

```bash
# 查看 Android 日志
adb logcat | grep -i "sing-box\|vpn"

# 安装 APK
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk

# 运行调试
flutter run -d <device-id>
```

## 完整的项目结构

```
vpn_client_demo/
├── android/
│   └── app/
│       ├── libs/
│       │   └── libbox.aar           # ✅ Go 绑定库
│       └── src/main/
│           ├── kotlin/
│           │   └── com/example/demo2/
│           │       ├── MainActivity.kt        # ✅ MethodChannel
│           │       ├── VpnService.kt          # ✅ VPN 服务
│           │       ├── PlatformInterfaceImpl.kt  # ✅ 平台接口
│           │       └── VpnHelper.kt           # ✅ 辅助类
│           └── AndroidManifest.xml   # ✅ 权限和服务
├── lib/
│   ├── utils/
│   │   ├── android_vpn_helper.dart  # ✅ Android VPN 封装
│   │   ├── node_config_converter.dart  # ✅ 已有（复用）
│   │   └── singbox_manager.dart     # Windows 专用
│   └── pages/
│       └── home_page.dart           # ✅ 添加平台判断
└── srss/                            # ✅ 规则文件（复用）
```

## 预估时间表

| 阶段 | 任务 | 时间 |
|------|------|------|
| 1 | 准备环境、获取 libbox.aar | 1 天 |
| 2 | 创建 VpnService 和接口 | 2-3 天 |
| 3 | Flutter MethodChannel 桥接 | 1 天 |
| 4 | 修改 Flutter 代码 | 1 天 |
| 5 | UI 适配和优化 | 1 天 |
| 6 | 测试和调试 | 2-3 天 |
| **总计** | | **8-10 天** |

## 第一步：立即开始

让我帮你开始第一步：

### 1. 创建必需的目录和文件

要开始吗？我可以帮你：
1. ✅ 创建 Android Kotlin 文件
2. ✅ 修改 AndroidManifest.xml
3. ✅ 创建 AndroidVpnHelper
4. ✅ 修改 home_page.dart 添加平台判断

需要我现在开始创建这些文件吗？

## 注意事项

1. **libbox.aar 获取**：
   - 可以从 NekoBox 提取
   - 或从 sing-box Release 下载
   - 或自己编译（需要 Go 环境）

2. **TUN vs Mixed**：
   - Windows：Mixed (HTTP/SOCKS 代理)
   - Android：TUN (虚拟网卡)
   - 配置生成需要区分

3. **测试设备**：
   - 需要 Android 5.0+ 设备
   - 推荐使用真机测试
   - 模拟器可能不支持 VPN

准备好开始了吗？🚀

