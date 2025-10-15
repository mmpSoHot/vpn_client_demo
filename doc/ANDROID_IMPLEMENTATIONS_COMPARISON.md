# Android VPN 实现方式对比

## 三个项目的对比

| 项目 | 核心 | Go 绑定库 | 编译工具 | 库名称 |
|------|------|-----------|----------|--------|
| **sing-box-for-android** | sing-box | ✅ 是 | gomobile | libbox.aar |
| **NekoBoxForAndroid** | sing-box | ✅ 是 | gomobile-matsuri | libcore.aar |
| **FlClash** | Clash.Meta | ✅ 是 | gomobile | libclash.so |
| **karing** | sing-box | ✅ 是 | gomobile | (vpn_service 插件) |

**结论**：所有 Android VPN 项目都使用 **Go 绑定库**！

## Go 绑定库的生成方式

### sing-box-for-android 方式

```bash
# 使用官方 gomobile
gomobile bind \
  -v \
  -androidapi 21 \
  -javapkg=io.nekohasekai \
  -libname=box \
  -tags with_clash_api \
  -o libbox.aar \
  ./libbox
```

**输出**：`libbox.aar`

### NekoBoxForAndroid 方式

```bash
# 使用改进的 gomobile-matsuri
gomobile-matsuri bind \
  -v \
  -androidapi 21 \
  -cache ".build" \
  -trimpath \
  -ldflags='-s -w' \
  -tags='with_conntrack,with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api' \
  . || exit 1
```

**输出**：`libcore.aar`

**放置位置**：`app/libs/libcore.aar`

### 关键区别

| 特性 | gomobile | gomobile-matsuri |
|------|----------|------------------|
| 来源 | Go 官方 | SagerNet 改进版 |
| 功能 | 基础 | 增强（更多编译选项） |
| 优化 | 标准 | 更好（-trimpath, -ldflags） |

## 使用 Go 绑定库的代码

### 1. 引入依赖

```gradle
// app/build.gradle
dependencies {
    // 从 libs 目录引入
    implementation(fileTree("libs"))
    // 这会自动引入 app/libs/libcore.aar
}
```

### 2. Kotlin 代码调用

**sing-box-for-android**：
```kotlin
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.BoxService

val service = Libbox.newService(configJson, platformInterface)
service.start()
```

**NekoBoxForAndroid**：
```kotlin
import libcore.Libcore
import libcore.BoxInstance

val box = Libcore.newSingBoxInstance(configJson, localResolver)
box.start()
```

**相似度**：99% 相同！

### 3. 平台接口实现

所有项目都需要实现：

```kotlin
interface PlatformInterface {
    // 保护 socket（不被 VPN 路由）
    fun autoDetectInterfaceControl(fd: Int)
    
    // 打开 TUN 接口
    fun openTun(options: TunOptions): Int
    
    // 写日志
    fun writeLog(message: String)
    
    // 发送通知
    fun sendNotification(notification: Notification)
}
```

## 完整的实现流程

### 第 1 步：编译 Go 绑定库

**选项 A - 使用预编译的库**（推荐）：
- 从 sing-box Release 下载
- 从 NekoBox Release 提取

**选项 B - 自己编译**：
```bash
# 1. 安装 Go
# 2. 安装 gomobile
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

# 3. 编译
cd sing-box/libbox
gomobile bind -target=android -androidapi=21 -o libbox.aar
```

### 第 2 步：创建 Android VPN Service

```kotlin
// VpnService.kt
class VpnService : VpnService() {
    private var boxInstance: BoxInstance? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 1. 读取配置
        val config = loadConfig()
        
        // 2. 创建平台接口
        val platform = object : PlatformInterface {
            override fun autoDetectInterfaceControl(fd: Int) {
                protect(fd)
            }
            
            override fun openTun(options: TunOptions): Int {
                val builder = Builder()
                    .setSession("VPN Demo")
                    .setMtu(options.mtu)
                    .addAddress("172.19.0.1", 30)
                    .addRoute("0.0.0.0", 0)
                    .addDnsServer("8.8.8.8")
                
                val pfd = builder.establish()
                return pfd.fd
            }
            
            override fun writeLog(message: String) {
                Log.d("sing-box", message)
            }
            
            override fun sendNotification(notification: Notification) {
                showNotification(notification)
            }
        }
        
        // 3. 创建并启动 sing-box
        boxInstance = Libcore.newSingBoxInstance(config, platform)
        boxInstance?.start()
        
        return START_STICKY
    }
    
    override fun onDestroy() {
        boxInstance?.close()
        super.onDestroy()
    }
}
```

### 第 3 步：Flutter MethodChannel

```dart
// lib/utils/android_vpn_helper.dart
class AndroidVpnHelper {
  static const MethodChannel _channel = MethodChannel('vpn_service');
  
  static Future<bool> start(NodeModel node) async {
    // 生成配置
    final config = NodeConfigConverter.generateFullConfig(node: node);
    
    // 调用 Android
    final result = await _channel.invokeMethod('start', {
      'config': jsonEncode(config),
    });
    
    return result == true;
  }
  
  static Future<bool> stop() async {
    return await _channel.invokeMethod('stop') == true;
  }
}
```

### 第 4 步：MainActivity 处理

```kotlin
// MainActivity.kt
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor, "vpn_service")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val config = call.argument<String>("config")
                        startVpn(config)
                        result.success(true)
                    }
                    "stop" -> {
                        stopVpn()
                        result.success(true)
                    }
                }
            }
    }
}
```

## 文件结构

```
我们的项目（Android 版本）/
├── android/
│   └── app/
│       ├── libs/
│       │   └── libcore.aar          # Go 绑定库
│       └── src/main/kotlin/
│           └── VpnService.kt        # VPN 服务实现
├── lib/
│   ├── utils/
│   │   ├── android_vpn_helper.dart  # Android VPN 辅助类
│   │   ├── node_config_converter.dart  # ✅ 已有，直接复用
│   │   └── singbox_manager.dart     # Windows 专用
│   └── pages/
│       └── home_page.dart           # ✅ 已有，添加平台判断
└── ...
```

## 代码复用

我们可以复用的代码：

✅ **100% 复用**：
- `node_config_converter.dart` - 配置生成
- `node_model.dart` - 数据模型
- `api_service.dart` - API 调用
- `user_service.dart` - 用户管理
- 所有 UI 页面（需要微调）

❌ **需要新写**：
- Android VpnService (Kotlin)
- PlatformInterface 实现 (Kotlin)
- MethodChannel 桥接 (Kotlin + Dart)
- AndroidManifest 配置

## 工作量估算

假设使用预编译的 libcore.aar：

| 任务 | 时间 | 难度 |
|------|------|------|
| 添加 libcore.aar | 0.5 天 | 简单 |
| 实现 VpnService | 2 天 | 中等 |
| 实现 PlatformInterface | 1 天 | 中等 |
| MethodChannel 桥接 | 1 天 | 简单 |
| UI 适配 | 1 天 | 简单 |
| 权限和通知 | 1 天 | 中等 |
| 测试和调试 | 2 天 | 中等 |
| **总计** | **8-9 天** | **中等** |

## 最终建议

### 当前（Windows v1.0）✅

**已完成**：
- ✅ 完整的 VPN 功能
- ✅ 配置生成（可复用到 Android）
- ✅ UI 界面（可复用到 Android）
- ✅ 打包方案

**下一步**：
1. 创建 Windows 安装包
2. 发布 v1.0
3. 收集用户反馈

### 未来（Android v2.0）

**实现路径**：
1. 获取 libcore.aar（从 NekoBox 或自己编译）
2. 参考 NekoBox 的 VpnService 实现
3. 复用我们的配置生成逻辑
4. 添加 MethodChannel 桥接
5. 测试和发布

**优势**：
- ✅ 有成熟的参考代码（NekoBox）
- ✅ 可以复用大部分 Dart 代码
- ✅ Go 绑定库性能好

---

**总结**：是的，所有 Android 实现都使用 Go 绑定库。但这不应该阻碍我们先发布 Windows 版本！

## 相关文件

- `参考项目/NekoBoxForAndroid-main/libcore/` - Go 核心代码
- `参考项目/NekoBoxForAndroid-main/libcore/build.sh` - 编译脚本
- `参考项目/NekoBoxForAndroid-main/app/src/main/java/.../bg/proto/BoxInstance.kt` - 使用示例

