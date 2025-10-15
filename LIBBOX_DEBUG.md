# libbox.aar 识别问题诊断

## 当前问题

编译时出现 `Unresolved reference 'libbox'` 错误,说明 Gradle 无法找到 libbox 包中的类。

## 已完成的修复

### 1. 确认文件存在
```
✅ libbox.aar 已存在: android/app/libs/libbox.aar (64MB)
```

### 2. 更新 Gradle 配置

**android/app/build.gradle.kts** 已修改为:

```kotlin
android {
    // ... 其他配置
    
    // 配置 AAR 仓库
    repositories {
        flatDir {
            dirs("libs")
        }
    }
}

dependencies {
    // 使用明确的文件路径
    implementation(files("libs/libbox.aar"))
    
    // ... 其他依赖
}
```

## 可能的原因

### 原因 1: libbox.aar 版本不兼容

你的 libbox.aar 可能是旧版本,API 接口可能不同。

**检查方法**:
```bash
# 解压 AAR 查看内容
cd android/app/libs
unzip -l libbox.aar
```

**预期应该包含**:
- classes.jar (包含 libbox 类)
- AndroidManifest.xml
- jni/ 目录 (包含 .so 文件)

### 原因 2: AAR 文件损坏

**检查方法**:
```bash
# 验证 AAR 是否是有效的 ZIP 文件
unzip -t libbox.aar
```

### 原因 3: Kotlin/Gradle 版本不兼容

libbox 可能需要特定的 Kotlin 版本。

## 解决方案

### 方案 A: 获取正确版本的 libbox.aar

从官方渠道获取最新版本:

1. **sing-box 官方发布**
   ```bash
   # 访问 https://github.com/SagerNet/sing-box/releases
   # 下载适合 Android 的版本
   ```

2. **使用 sing-box-for-android 的版本**
   ```bash
   git clone https://github.com/SagerNet/sing-box-for-android
   # 从项目中提取 libbox
   ```

### 方案 B: 使用 Maven 依赖 (如果有)

某些 libbox 版本可能已发布到 Maven:

```kotlin
// android/app/build.gradle.kts
repositories {
    mavenCentral()
    maven { url = uri("https://jitpack.io") }
}

dependencies {
    implementation("io.github.sagernet:libbox:VERSION")
}
```

### 方案 C: 回退到临时实现

如果无法获取兼容的 libbox,可以先注释掉 libbox 相关代码,使用临时 VPN 实现:

**VpnService.kt**:
```kotlin
// 注释掉这些 import
// import libbox.Libbox
// import libbox.BoxService

// private var boxInstance: BoxService? = null

private fun startVpn(configJson: String) {
    try {
        Log.d(TAG, "启动 VPN (临时实现)...")
        
        // 显示前台服务通知
        startForeground(NOTIFICATION_ID, createNotification())
        
        // 临时: 创建一个空 VPN 接口
        val builder = Builder()
        builder.setSession("VPN Demo")
        builder.addAddress("10.0.0.2", 32)
        builder.addRoute("0.0.0.0", 0)
        builder.addDnsServer("8.8.8.8")
        
        val vpnInterface = builder.establish()
        
        if (vpnInterface != null) {
            Log.d(TAG, "✅ VPN 接口已建立 (测试模式)")
        } else {
            Log.e(TAG, "❌ VPN 接口建立失败")
            stopSelf()
        }
        
    } catch (e: Exception) {
        Log.e(TAG, "启动 VPN 失败", e)
        stopSelf()
    }
}
```

**PlatformInterfaceImpl.kt**:
```kotlin
// 全部注释掉或删除
```

## 推荐的 libbox.aar 来源

### 1. karing 项目 (推荐)

karing 是一个成熟的 Flutter VPN 项目,包含了编译好的 libbox:

```bash
git clone --depth 1 https://github.com/KaringX/karing
# 查找 libbox.aar 文件
find karing -name "libbox.aar"
# 复制到你的项目
cp karing/.../libbox.aar android/app/libs/
```

### 2. FlClash 项目

另一个 Flutter VPN 项目:

```bash
git clone --depth 1 https://github.com/chen08209/FlClash
# 查找并复制 libbox
```

### 3. 自己编译 (最可靠)

从源码编译确保兼容性:

```bash
# 1. 克隆 sing-box
git clone https://github.com/SagerNet/sing-box
cd sing-box

# 2. 安装依赖
# 需要: Go 1.20+, Android NDK, Gomobile

# 3. 编译
make lib_install

# 4. 产物位于
# libbox/build/outputs/aar/libbox-release.aar
```

## 验证 libbox.aar 内容

解压并检查:

```bash
cd android/app/libs
mkdir temp
cd temp
unzip ../libbox.aar

# 检查 classes.jar 中的类
jar tf classes.jar | grep libbox

# 应该看到类似:
# libbox/Libbox.class
# libbox/BoxService.class
# libbox/PlatformInterface.class
# libbox/TunOptions.class
# ...
```

## 快速测试方法

### 测试 1: 检查 AAR 是否被识别

在 `MainActivity.kt` 中临时添加:

```kotlin
import libbox.Libbox  // 如果这行报错,说明 AAR 未被识别

class MainActivity : FlutterActivity() {
    init {
        try {
            // 尝试访问 Libbox 类
            val version = Libbox.version()  // 某些版本有这个方法
            Log.d("MainActivity", "libbox version: $version")
        } catch (e: Exception) {
            Log.e("MainActivity", "libbox 不可用: $e")
        }
    }
}
```

### 测试 2: 检查 Gradle 同步

```bash
cd android
./gradlew :app:dependencies | grep libbox
```

应该能看到 libbox.aar 被列出。

## 下一步行动

1. **等待当前构建完成** - 查看是否还是同样的错误
2. **如果还是报错** - 说明 libbox.aar 版本不兼容,需要更换
3. **获取新的 libbox.aar** - 从 karing 或 FlClash 项目中提取
4. **或使用临时实现** - 先让应用能运行起来

## 联系我

如果构建完成后还是同样的错误,请提供:
1. libbox.aar 的来源 (从哪里获取的)
2. libbox.aar 的大小 (已知是 64MB)
3. 是否能解压 AAR 并查看其中的类

