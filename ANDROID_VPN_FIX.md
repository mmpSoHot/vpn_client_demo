# Android VPN 启动失败 - 快速修复指南

## 🔴 问题确认

你遇到的错误是:**Android VPN 启动失败**

## 🎯 根本原因

当前代码是一个**骨架实现**,核心的 VPN 功能代码被注释掉了,因为缺少 **libbox.aar** 库文件。

### 当前状态
- ✅ VPN 权限请求 - 正常
- ✅ VPN 服务注册 - 正常  
- ✅ Flutter 通信 - 正常
- ❌ **VPN 核心逻辑 - 被注释掉了!**

查看文件 `android/app/src/main/kotlin/com/example/demo2/VpnService.kt` 第 71-81 行:

```kotlin
/* TODO: 获取 libbox.aar 后取消注释以下代码

// 创建平台接口
val platformInterface = PlatformInterfaceImpl(this)

// 创建 sing-box 实例
boxInstance = Libbox.newService(configJson, platformInterface)

// 启动 sing-box
boxInstance?.start()

*/
```

**这些是真正启动 VPN 的代码,但被注释掉了!**

## ✅ 解决方案

### 方案 1: 获取 libbox.aar (推荐 - 完整功能)

#### 1.1 下载预编译的 libbox.aar

从以下来源之一获取:

**选项 A: sing-box 官方发布**
```bash
# 从 GitHub Releases 下载
# https://github.com/SagerNet/sing-box/releases
# 下载 sing-box-<version>-android-arm64-v8a.aar
```

**选项 B: 自己编译**
```bash
git clone https://github.com/SagerNet/sing-box
cd sing-box
make lib_install
# 产物: libbox/build/outputs/aar/libbox-release.aar
```

**选项 C: 使用其他开源项目的**
从这些项目中提取 libbox.aar:
- https://github.com/SagerNet/sing-box-for-android
- https://github.com/Mahdi-Rahmani/flutter-libbox

#### 1.2 放置文件

```bash
# 复制到项目中
cp libbox-release.aar android/app/libs/libbox.aar
```

#### 1.3 取消代码注释

编辑 `android/app/src/main/kotlin/com/example/demo2/VpnService.kt`:

```kotlin
// 第 13-14 行: 取消注释
import libbox.Libbox
import libbox.BoxService

// 第 25 行: 取消注释
private var boxInstance: BoxService? = null

// 第 71-81 行: 取消注释
// 创建平台接口
val platformInterface = PlatformInterfaceImpl(this)

// 创建 sing-box 实例
boxInstance = Libbox.newService(configJson, platformInterface)

// 启动 sing-box
boxInstance?.start()

// 第 99-102 行: 取消注释
boxInstance?.close()
boxInstance = null
```

编辑 `android/app/src/main/kotlin/com/example/demo2/PlatformInterfaceImpl.kt`:
- 全部取消注释

#### 1.4 重新构建

```bash
flutter clean
flutter pub get
flutter run
```

### 方案 2: 临时测试实现 (快速验证流程)

如果只是想**快速测试流程**,可以实现一个最小的 VPN 接口:

编辑 `android/app/src/main/kotlin/com/example/demo2/VpnService.kt`,修改 `startVpn` 函数:

```kotlin
private fun startVpn(configJson: String) {
    try {
        Log.d(TAG, "启动 VPN...")
        Log.d(TAG, "配置: $configJson")
        
        // 方案 2: 临时测试实现 - 创建一个空 VPN 接口
        val builder = Builder()
        builder.setSession("VPN Demo Test")
        builder.addAddress("10.0.0.2", 32)
        builder.addRoute("0.0.0.0", 0)
        builder.addDnsServer("8.8.8.8")
        
        val vpnInterface = builder.establish()
        
        if (vpnInterface != null) {
            Log.d(TAG, "✅ VPN 接口创建成功 (测试模式)")
            
            // 显示前台服务通知
            startForeground(NOTIFICATION_ID, createNotification())
            
            // 保存接口引用 (需要添加成员变量)
            // 注意: 这个实现不会真正代理流量!
            
        } else {
            Log.e(TAG, "❌ VPN 接口创建失败")
            stopSelf()
        }
        
    } catch (e: Exception) {
        Log.e(TAG, "启动 VPN 失败", e)
        stopSelf()
    }
}
```

**⚠️ 警告**: 这只是测试代码,**不会真正代理流量**!仅用于验证 VPN 权限、服务启动等流程是否正常。

### 方案 3: 使用 flutter_vpn 插件 (替代方案)

如果 libbox 集成太复杂,可以考虑使用现成的 Flutter VPN 插件:

```yaml
# pubspec.yaml
dependencies:
  flutter_vpn: ^2.0.0  # 示例
```

但这需要重写很多代码,不推荐。

## 🚀 推荐步骤

我建议按以下顺序进行:

### 第一步: 验证当前框架是否正常

先运行方案 2 (临时测试实现),验证:
1. VPN 权限能否正常申请
2. VPN 服务能否启动
3. 通知是否正常显示
4. Flutter 与 Android 通信是否正常

### 第二步: 获取 libbox.aar

从 sing-box 官方或其他来源获取 `libbox.aar`

### 第三步: 集成 libbox

按方案 1 的步骤完整集成

## 📋 验证清单

完成后,验证以下几点:

- [ ] 点击连接按钮后,应用请求 VPN 权限
- [ ] 授予权限后,通知栏显示 "VPN 已连接"
- [ ] Android 设置 → VPN 中显示活跃连接
- [ ] 使用方案 1 时,网络流量正常代理
- [ ] 点击断开后,VPN 正常关闭

## 🔍 调试方法

### 查看详细日志

```bash
# Flutter 日志
flutter run -v

# Android 系统日志  
adb logcat | grep -E "VpnService|MainActivity|libbox"

# 过滤关键信息
adb logcat | grep -E "启动 VPN|VPN.*成功|VPN.*失败"
```

### 常见错误

1. **"Unresolved reference: Libbox"**
   - 原因: libbox.aar 未正确放置
   - 解决: 检查 `android/app/libs/libbox.aar` 是否存在

2. **"VPN 接口创建失败"**
   - 原因: 没有 VPN 权限
   - 解决: 确保正确请求了权限

3. **"Permission Denial"**
   - 原因: AndroidManifest.xml 配置问题
   - 解决: 已修复,检查 service 配置

## 📚 相关文档

- [详细排查指南](doc/ANDROID_VPN_TROUBLESHOOTING.md)
- [libbox 使用说明](android/app/libs/README_LIBBOX.md)
- [Android VPN 实现文档](doc/ANDROID_VPN_IMPLEMENTATION.md)

## 💡 总结

**现在的问题**: 核心代码被注释了,因为缺少 libbox.aar

**最快的解决方案**: 
1. 先用方案 2 验证流程 (5分钟)
2. 获取 libbox.aar (需要下载/编译)
3. 按方案 1 完整集成 (10分钟)

**预期时间**: 
- 方案 2: 5-10 分钟
- 方案 1: 30-60 分钟 (取决于 libbox 获取速度)

