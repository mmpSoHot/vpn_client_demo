# 如何获取正确的 libbox.aar

## 当前状态

✅ **应用现在可以运行**,使用临时测试实现
❌ **但不会真正代理流量**,需要正确的 libbox.aar

### 临时实现的功能

当前代码会:
- ✅ 请求 VPN 权限
- ✅ 创建 VPN 接口
- ✅ 显示前台通知
- ❌ **不会代理流量** (只是一个空 VPN)

## 问题分析

你当前的 `libbox.aar` (64MB) **无法被 Gradle 识别**,可能原因:
1. 版本太旧,API 已变更
2. 编译时使用的 Go/NDK 版本不兼容
3. 文件损坏

## 解决方案: 获取正确的 libbox.aar

### 方案 1: 从 karing 项目获取 (最推荐⭐⭐⭐⭐⭐)

karing 是一个成熟的开源 VPN 项目,已经包含编译好的 libbox。

```bash
# 1. 克隆 karing 仓库 (只需要最近的提交)
git clone --depth 1 https://github.com/KaringX/karing.git

# 2. 查找 libbox.aar
cd karing
find . -name "libbox.aar" -o -name "*libbox*.aar"

# 可能的位置:
# - android/app/libs/
# - packages/libbox/

# 3. 复制到你的项目
cp android/app/libs/libbox.aar D:/Workspace/flutter/vpn_client_demo/android/app/libs/

# 4. 清理并重新构建你的项目
cd D:/Workspace/flutter/vpn_client_demo
flutter clean
flutter run
```

### 方案 2: 从 FlClash 项目获取 (推荐⭐⭐⭐⭐)

FlClash 也是一个优秀的 Flutter VPN 项目。

```bash
# 1. 克隆 FlClash
git clone --depth 1 https://github.com/chen08209/FlClash.git

# 2. 查找 libbox
cd FlClash
find . -name "*libbox*.aar"

# 3. 复制
cp <找到的路径>/libbox.aar D:/Workspace/flutter/vpn_client_demo/android/app/libs/
```

### 方案 3: 从 sing-box 官方发布下载 (推荐⭐⭐⭐)

访问 sing-box GitHub Releases 页面下载预编译版本。

1. 打开浏览器,访问:
   ```
   https://github.com/SagerNet/sing-box/releases
   ```

2. 查找最新版本,下载包含 "android" 的文件,例如:
   ```
   sing-box-1.x.x-android-universal.apk
   ```

3. 从 APK 中提取 libbox.aar:
   ```bash
   # APK 本质是 ZIP 文件
   unzip sing-box-1.x.x-android-universal.apk -d sing-box-android
   
   # 查找 .so 文件
   find sing-box-android -name "*.so"
   
   # 但这种方法可能无法直接获得 AAR,需要手动打包
   ```

### 方案 4: 自己编译 libbox (最可靠但复杂⭐⭐⭐⭐⭐)

这是最可靠的方法,但需要配置环境。

#### 环境要求:
- Go 1.21+ 
- Android NDK r26+
- gomobile

#### 编译步骤:

```bash
# 1. 安装 Go (如果没有)
# 访问 https://golang.org/dl/ 下载安装

# 2. 克隆 sing-box
git clone https://github.com/SagerNet/sing-box.git
cd sing-box

# 3. 安装 gomobile
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest

# 4. 初始化 gomobile
gomobile init

# 5. 设置 Android NDK 路径
export ANDROID_NDK_HOME=/path/to/your/android/ndk

# 6. 编译 libbox
make lib_install

# 7. 产物位于
# libbox/build/outputs/aar/libbox-release.aar

# 8. 复制到你的项目
cp libbox/build/outputs/aar/libbox-release.aar \
   D:/Workspace/flutter/vpn_client_demo/android/app/libs/libbox.aar
```

## 验证 libbox.aar 是否正确

### 方法 1: 检查 AAR 内容

```bash
cd android/app/libs

# 解压 AAR (AAR 是 ZIP 格式)
mkdir temp
cd temp
unzip ../libbox.aar

# 查看目录结构
ls -la

# 应该包含:
# - AndroidManifest.xml
# - classes.jar
# - jni/
#   - arm64-v8a/
#   - armeabi-v7a/
#   - x86/
#   - x86_64/
# - R.txt
# - res/

# 查看 classes.jar 中的类
jar tf classes.jar | grep libbox

# 应该看到:
# libbox/Libbox.class
# libbox/BoxService.class
# libbox/PlatformInterface.class
# libbox/TunOptions.class
# ... 等等
```

### 方法 2: 测试编译

替换 libbox.aar 后:

```bash
# 1. 清理
flutter clean

# 2. 在 VpnService.kt 中取消注释:
# import libbox.Libbox
# import libbox.BoxService

# 3. 编译
flutter build apk --debug

# 如果编译通过,说明 AAR 正确
```

## 替换 libbox.aar 后的步骤

### 1. 备份当前的 libbox.aar

```bash
cd android/app/libs
mv libbox.aar libbox.aar.old
```

### 2. 放置新的 libbox.aar

```bash
# 从 karing 或其他来源复制
cp /path/to/correct/libbox.aar ./libbox.aar
```

### 3. 取消代码注释

编辑以下文件:

**VpnService.kt**:
```kotlin
// 取消这些行的注释:
import libbox.Libbox
import libbox.BoxService

private var boxInstance: BoxService? = null

// 在 startVpn() 中:
val platformInterface = PlatformInterfaceImpl(this)
boxInstance = Libbox.newService(configJson, platformInterface)
boxInstance?.start()

// 在 stopVpn() 中:
boxInstance?.close()
boxInstance = null
```

**PlatformInterfaceImpl.kt**:
```kotlin
// 取消所有注释
import libbox.PlatformInterface
import libbox.TunOptions
import libbox.Notification as BoxNotification

class PlatformInterfaceImpl(...) : PlatformInterface {
    // 取消所有方法的注释
}
```

### 4. 清理并构建

```bash
flutter clean
flutter pub get
flutter run
```

### 5. 验证

运行后查看日志:

```
D/VpnService: 启动 VPN...
D/PlatformInterface: 打开 TUN 接口...
D/PlatformInterface: ✅ TUN 接口已建立: fd=123
D/sing-box: [INFO] sing-box started
D/VpnService: ✅ VPN 启动成功
```

如果看到这些日志,说明成功!

## 推荐顺序

1. **首选**: 从 karing 项目获取 (最快最简单)
2. **备选**: 从 FlClash 获取
3. **进阶**: 自己编译 (最可靠)

## karing 项目快速获取指南

这是最推荐的方法,以下是详细步骤:

```bash
# 在 PowerShell 中执行

# 1. 进入临时目录
cd D:\Temp

# 2. 克隆 karing (只克隆最新版本)
git clone --depth 1 https://github.com/KaringX/karing.git

# 3. 查找 libbox.aar
cd karing
Get-ChildItem -Recurse -Filter "libbox.aar"

# 或使用 dir 命令
dir /s libbox.aar

# 4. 找到后复制到你的项目
# 假设找到在: android\app\libs\libbox.aar
cp android\app\libs\libbox.aar D:\Workspace\flutter\vpn_client_demo\android\app\libs\libbox.aar

# 5. 回到你的项目
cd D:\Workspace\flutter\vpn_client_demo

# 6. 清理构建
flutter clean

# 7. 取消 VpnService.kt 和 PlatformInterfaceImpl.kt 中的注释

# 8. 运行
flutter run
```

## 当前临时实现的限制

现在的代码会:
- ✅ 创建 VPN 连接
- ✅ 显示 "已连接" 状态
- ✅ Android 系统显示 VPN 图标
- ❌ **流量不会通过代理** (只是一个空 VPN)

所以你可以测试:
- VPN 权限申请流程
- 连接/断开 UI 交互
- 通知显示

但无法测试:
- 实际的代理功能
- 网站访问
- 速度统计

## 需要帮助?

如果遇到问题,请提供:
1. libbox.aar 的来源
2. 解压后的内容列表
3. 编译错误信息

## 快速检查清单

- [ ] 删除旧的 libbox.aar
- [ ] 从 karing/FlClash 获取新的 libbox.aar  
- [ ] 放置到 `android/app/libs/libbox.aar`
- [ ] 解压验证包含 `libbox/` 类
- [ ] 取消 VpnService.kt 注释
- [ ] 取消 PlatformInterfaceImpl.kt 注释
- [ ] `flutter clean`
- [ ] `flutter run`
- [ ] 查看日志确认 sing-box 启动

完成这些步骤后,你的 Android VPN 就能真正工作了! 🎉

