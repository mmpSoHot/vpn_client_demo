# Android 版本快速开始指南

## 🎯 当前状态

✅ **已完成**：
- Android VPN 服务代码（Kotlin）
- Flutter 平台适配
- MethodChannel 桥接
- 配置文件

⚠️ **待完成**：
- 获取 libbox.aar（sing-box Android 绑定库）

## 🚀 快速开始（3 步）

### 第 1 步：获取 libbox.aar

选择以下**任意一种**方式：

#### 方式 A：从参考项目提取（最快 5 分钟）

```bash
# 查看 NekoBox 项目
cd 参考项目/NekoBoxForAndroid-main/app/libs/

# 如果有 libcore.aar，复制到我们的项目
cp libcore.aar ../../../../android/app/libs/libbox.aar

# 验证
ls -lh ../../../../android/app/libs/libbox.aar
```

#### 方式 B：从 sing-box Release 下载（10 分钟）

1. 访问：https://github.com/SagerNet/sing-box/releases
2. 找到最新版本，下载 `sing-box-<version>-android.aar`
3. 重命名为 `libbox.aar`
4. 放置到 `android/app/libs/` 目录

#### 方式 C：自己编译（1-2 小时）

```bash
# 1. 安装 Go 1.21+
# https://go.dev/dl/

# 2. 安装 gomobile
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

# 3. 克隆 sing-box
git clone https://github.com/SagerNet/sing-box.git
cd sing-box/experimental/libbox

# 4. 编译
gomobile bind -target=android -androidapi=21 -o libbox.aar

# 5. 复制到项目
cp libbox.aar /d/Workspace/flutter/vpn_client_demo/android/app/libs/
```

### 第 2 步：取消代码注释

获取 libbox.aar 后，取消以下文件中的注释：

#### `android/app/src/main/kotlin/com/example/demo2/VpnService.kt`

```kotlin
// 1. 取消 import 注释
import libbox.Libbox
import libbox.BoxService

// 2. 取消字段注释
private var boxInstance: BoxService? = null

// 3. 取消 startVpn 中的实现注释
// 搜索 "TODO: 获取 libbox.aar 后取消注释"
// 取消整个代码块的注释

// 4. 取消 stopVpn 中的实现注释
boxInstance?.close()
boxInstance = null
```

#### `android/app/src/main/kotlin/com/example/demo2/PlatformInterfaceImpl.kt`

```kotlin
// 1. 取消 import 注释
import libbox.PlatformInterface
import libbox.TunOptions
import libbox.Notification as BoxNotification

// 2. 取消接口继承注释
class PlatformInterfaceImpl(...) : PlatformInterface {

// 3. 取消所有方法的注释
override fun autoDetectInterfaceControl(fd: Long) { ... }
override fun openTun(options: TunOptions): Long { ... }
override fun writeLog(message: String) { ... }
override fun sendNotification(notification: BoxNotification) { ... }
```

### 第 3 步：编译测试

```bash
# 连接 Android 设备或启动模拟器
adb devices

# 运行
flutter run -d <device-id>

# 或构建 APK
flutter build apk --release
```

## 🧪 测试流程

1. **启动应用** ✅
2. **登录账号** ✅
3. **选择节点** ✅
4. **点击连接**：
   - 系统弹出 VPN 权限请求
   - 点击"确定"授予权限
   - VPN 连接成功
5. **测试功能**：
   - 切换节点
   - 切换代理模式（绕过大陆/全局代理）
   - 查看网速统计
   - 断开 VPN
6. **退出应用** ✅

## 📊 预期结果

### 连接成功后

- ✅ 顶部状态栏显示 VPN 图标（钥匙）
- ✅ 通知栏显示"VPN 已连接"
- ✅ 应用内状态显示"已连接"
- ✅ 网速统计实时更新
- ✅ 可以访问外部网络

### 日志输出

```
🤖 Android 平台，使用 VPN 服务
🚀 Android VPN 启动中...
   节点: 🇺🇸 美国|01|0.8x|【新】
   模式: 绕过大陆
✅ 配置文件已生成
✅ VPN 启动成功
✅ Android VPN 启动成功
```

## 🔧 故障排除

### 问题 1：libbox.aar 找不到

```
error: package libbox does not exist
```

**解决**：
- 确认 `android/app/libs/libbox.aar` 存在
- 运行 `flutter clean` 后重新编译

### 问题 2：VPN 权限被拒绝

```
Failed to establish VPN
```

**解决**：
- 重新启动应用
- 手动到系统设置中授予 VPN 权限

### 问题 3：编译错误

```
Android resource linking failed
```

**解决**：
- 检查 `build.gradle.kts` 是否正确配置
- 运行 `flutter pub get`
- 运行 `flutter clean`

### 问题 4：无法连接网络

**检查**：
- sing-box 配置是否正确生成
- 节点是否可用
- 查看 Logcat 日志：`adb logcat | grep -i "sing-box\|vpn"`

## 📱 与 Windows 版本的区别

| 特性 | Windows | Android |
|------|---------|---------|
| 代理方式 | 系统代理 | VPN (TUN) |
| 权限 | 可选 | 必需（VPN） |
| 启动 | 独立进程 | 系统服务 |
| 通知 | 无 | 前台服务通知 |
| 监听端口 | 15808 | TUN 接口 |

## 📝 开发建议

### 先发布 Windows 版本 ✅

1. Windows 版本已完全可用
2. 无需额外依赖
3. 可以先收集用户反馈

### Android 作为 v2.0 🚀

1. 获取 libbox.aar 需要时间
2. 测试和调试需要专门的 Android 设备
3. 可以根据用户需求决定优先级

## 🎯 下一步

- [ ] 选择一种方式获取 libbox.aar
- [ ] 取消代码注释
- [ ] 编译测试
- [ ] 逐项测试功能清单
- [ ] 修复 Bug
- [ ] 发布 Android 版本

## 📚 相关文档

- 详细开发计划：`doc/ANDROID_DEVELOPMENT_PLAN.md`
- 实现对比：`doc/ANDROID_IMPLEMENTATIONS_COMPARISON.md`
- 实现总结：`doc/ANDROID_IMPLEMENTATION_SUMMARY.md`
- libbox 获取指南：`android/app/libs/README_LIBBOX.md`

---

**提示**：如果你现在就想测试，推荐使用**方式 A**从 NekoBox 提取 libcore.aar，5 分钟即可开始测试！

