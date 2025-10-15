# Android VPN 启动失败排查指南

## 问题现象
点击连接按钮后提示"Android VPN 启动失败,请检查 libbox.aar 是否已配置"

## 根本原因

当前 Android VPN 服务是一个**空实现**,因为缺少 `libbox.aar` 库文件。虽然服务可以启动并显示通知,但实际上**没有建立真正的 VPN 连接**。

### 代码分析

#### VpnService.kt (第 64-88 行)
```kotlin
private fun startVpn(configJson: String) {
    try {
        Log.d(TAG, "启动 VPN...")
        
        // 显示前台服务通知
        startForeground(NOTIFICATION_ID, createNotification())
        
        /* TODO: 获取 libbox.aar 后取消注释以下代码
        
        // 创建平台接口
        val platformInterface = PlatformInterfaceImpl(this)
        
        // 创建 sing-box 实例
        boxInstance = Libbox.newService(configJson, platformInterface)
        
        // 启动 sing-box
        boxInstance?.start()
        
        */
        
        Log.d(TAG, "✅ VPN 启动成功")
        
        // 临时实现：显示通知表示"启动"
        // 实际的 VPN 功能需要 libbox.aar
        
    } catch (e: Exception) {
        Log.e(TAG, "启动 VPN 失败", e)
        stopSelf()
    }
}
```

**关键问题**: 核心的 VPN 逻辑被注释掉了!

## 解决方案

### 方案 1: 获取并配置 libbox.aar (推荐)

这是**完整实现 Android VPN** 的正确方式。

#### 步骤:

1. **获取 libbox.aar**
   
   有两种方式:
   
   **方式 A: 从 sing-box 官方构建**
   ```bash
   # 克隆 sing-box 仓库
   git clone https://github.com/SagerNet/sing-box
   cd sing-box
   
   # 构建 Android AAR
   make lib_install
   ```
   
   构建产物位于: `libbox/build/outputs/aar/libbox-release.aar`
   
   **方式 B: 从参考项目复制**
   
   参考项目中已经包含了 libbox:
   - `参考项目/karing/` 
   - `参考项目/sing-box-for-android/`
   
   找到其中的 `libbox.aar` 文件复制过来

2. **放置 libbox.aar**
   ```bash
   # 复制到项目中
   cp libbox.aar android/app/libs/
   ```

3. **配置 build.gradle.kts**
   
   已经配置好了,在 `android/app/build.gradle.kts` 中:
   ```kotlin
   dependencies {
       // libbox (sing-box Android 库)
       implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))
       // ... 其他依赖
   }
   ```

4. **取消代码注释**
   
   在以下文件中取消相关代码的注释:
   
   - `android/app/src/main/kotlin/com/example/demo2/VpnService.kt`
     - 第 13-14 行: libbox 导入
     - 第 25 行: boxInstance 变量
     - 第 71-81 行: 启动 VPN 逻辑
     - 第 99-102 行: 停止 VPN 逻辑
   
   - `android/app/src/main/kotlin/com/example/demo2/PlatformInterfaceImpl.kt`
     - 全部取消注释

5. **重新构建**
   ```bash
   flutter clean
   flutter run
   ```

### 方案 2: 实现一个测试 VPN (临时方案)

如果只是测试流程,可以实现一个最小的 VPN 接口(不使用 libbox):

```kotlin
private fun startVpn(configJson: String) {
    try {
        Log.d(TAG, "启动 VPN...")
        
        // 创建 VPN 接口
        val builder = Builder()
        builder.setSession("VPN Demo")
        builder.addAddress("10.0.0.2", 32)  // 虚拟 IP
        builder.addRoute("0.0.0.0", 0)      // 路由所有流量
        builder.addDnsServer("8.8.8.8")     // DNS
        
        val vpnInterface = builder.establish()
        
        if (vpnInterface != null) {
            Log.d(TAG, "✅ VPN 接口创建成功")
            
            // 显示前台服务通知
            startForeground(NOTIFICATION_ID, createNotification())
            
            // TODO: 在这里处理网络数据包
            // 这是一个空实现,不会真正代理流量
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

**注意**: 这只是一个**测试实现**,不会真正代理流量!

## 当前状态总结

| 组件 | 状态 | 说明 |
|------|------|------|
| VPN 权限申请 | ✅ 已实现 | MainActivity.kt 中正确实现 |
| VPN 服务注册 | ✅ 已实现 | AndroidManifest.xml 中正确配置 |
| VPN 服务生命周期 | ✅ 已实现 | VpnService.kt 框架完整 |
| Flutter 集成 | ✅ 已实现 | AndroidVpnHelper 正确实现 |
| **VPN 核心逻辑** | ❌ **未实现** | **缺少 libbox.aar** |

## 验证步骤

完成配置后,通过以下方式验证:

1. **查看日志**
   ```bash
   flutter run
   # 或
   adb logcat | grep VpnService
   ```
   
   成功的日志应该包含:
   ```
   D/VpnService: 启动 VPN...
   D/VpnService: ✅ VPN 启动成功
   ```

2. **检查 VPN 状态**
   
   在 Android 设置中查看:
   - 设置 → 网络和互联网 → VPN
   - 应该显示 "demo2" 已连接

3. **测试网络**
   
   打开浏览器访问被墙网站,验证是否可以访问

## 参考文档

- [Android VPN 实现](./ANDROID_VPN_IMPLEMENTATION.md)
- [libbox 使用指南](../android/app/libs/README_LIBBOX.md)
- [sing-box 官方文档](https://sing-box.sagernet.org/)

## 快速开始 (推荐流程)

```bash
# 1. 从参考项目复制 libbox.aar
cp 参考项目/karing/android/app/libs/libbox.aar android/app/libs/

# 2. 清理并重新构建
flutter clean
flutter pub get

# 3. 运行
flutter run
```

构建成功后,取消 VpnService.kt 和 PlatformInterfaceImpl.kt 中的代码注释即可使用。

