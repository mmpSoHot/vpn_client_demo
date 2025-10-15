# libbox.aar 编译问题总结

## 问题现象

你重新编译的 libbox.aar (79KB classes.jar) 无法被 Gradle 识别,报错:
```
Unresolved reference 'libbox'
Unresolved reference 'PlatformInterface'  
Unresolved reference 'TunOptions'
```

## 根本原因

你编译的 libbox.aar **缺少 Kotlin/Java 类定义**,只包含了 JNI 库(.so 文件)。

### 正常的 libbox.aar 应该包含

```
libbox.aar/
├── classes.jar (应该 > 500KB,包含所有 Java/Kotlin 类)
│   └── libbox/
│       ├── Libbox.class
│       ├── BoxService.class
│       ├── PlatformInterface.class
│       ├── TunOptions.class
│       ├── ... 等等
├── jni/
│   ├── arm64-v8a/libbox.so
│   ├── armeabi-v7a/libbox.so
│   ├── x86/libbox.so
│   └── x86_64/libbox.so
├── AndroidManifest.xml
└── R.txt
```

### 你的 libbox.aar 包含

```
libbox.aar/
├── classes.jar (只有 79KB ❌ 太小了!)
├── jni/ (✅ 正常)
│   ├── arm64-v8a/
│   ├── armeabi-v7a/
│   ├── x86/
│   └── x86_64/
├── AndroidManifest.xml
└── R.txt
```

**问题**: classes.jar 太小,说明编译过程没有生成 Java 绑定类!

## 编译 libbox.aar 的正确方法

### 方法 1: 使用 gomobile (推荐)

```bash
# 1. 安装 Go
# 下载 https://golang.org/dl/

# 2. 克隆 sing-box
git clone https://github.com/SagerNet/sing-box
cd sing-box

# 3. 安装 gomobile
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest

# 4. 初始化 gomobile
export PATH=$PATH:$(go env GOPATH)/bin
gomobile init

# 5. 设置 Android SDK 和 NDK
export ANDROID_HOME=/path/to/android/sdk
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/26.0.10792818

# 6. 编译 libbox
cd libbox
gomobile bind -v -androidapi 21 -javapkg=libbox -libname=box -tags=with_clash_api .

# 产物: libbox.aar (应该 > 10MB)
```

### 方法 2: 使用 Makefile

```bash
cd sing-box

# 编译
make lib_install

# 产物位于
# libbox/build/outputs/aar/libbox-release.aar
```

### 方法 3: 使用 Gradle (在 sing-box-for-android 中)

```bash
git clone https://github.com/SagerNet/sing-box-for-android
cd sing-box-for-android

# 编译
./gradlew :libbox:assembleRelease

# 产物
# libbox/build/outputs/aar/libbox-release.aar
```

## 验证 libbox.aar 是否正确

### 1. 检查文件大小

```bash
# classes.jar 应该至少 500KB+
# 如果只有几十 KB,说明编译失败

cd libbox_temp
dir classes.jar

# 应该显示类似:
# -a----  1980/1/1   0:00   856432 classes.jar
```

### 2. 检查类是否存在

需要 JDK 的 jar 工具:

```bash
jar tf classes.jar | findstr libbox

# 应该看到:
# libbox/Libbox.class
# libbox/BoxService.class  
# libbox/PlatformInterface.class
# libbox/TunOptions.class
# libbox/CommandClient.class
# libbox/CommandServer.class
# ... 等等
```

### 3. 检查 JNI 库

```bash
cd jni/arm64-v8a
dir

# 应该看到:
# libbox.so (通常 10-20MB)
```

## 临时解决方案

在获取正确的 libbox.aar 之前,回退到临时实现:

### 1. 注释掉 libbox 相关代码

**VpnService.kt**:
```kotlin
// import libbox.Libbox
// import libbox.BoxService

// private var boxInstance: BoxService? = null

private fun startVpn(configJson: String) {
    // 临时:创建空 VPN
    val builder = Builder()
    builder.setSession("VPN Test")
    builder.addAddress("10.0.0.2", 32)
    builder.addRoute("0.0.0.0", 0)
    builder.addDnsServer("8.8.8.8")
    
    vpnInterface = builder.establish()
}
```

**PlatformInterfaceImpl.kt**:
```kotlin
// 全部注释或删除
```

### 2. 运行应用

```bash
flutter clean
flutter run
```

这样至少可以测试:
- VPN 权限申请
- UI 交互
- 连接/断开流程

但**不会真正代理流量**。

## 推荐的最快解决方案

### 不要自己编译,直接用现成的!

从其他成熟项目获取 libbox.aar:

```bash
# 方案 A: karing
git clone --depth 1 https://github.com/KaringX/karing
# 查找 libbox.aar
find karing -name "*.aar"

# 方案 B: FlClash  
git clone --depth 1 https://github.com/chen08209/FlClash
find FlClash -name "*libbox*.aar"

# 方案 C: sing-box-for-android (需要编译)
git clone https://github.com/SagerNet/sing-box-for-android
cd sing-box-for-android
./gradlew :libbox:assembleRelease
```

## 检查 libbox.aar 正确性的脚本

创建 `check_libbox.ps1`:

```powershell
# 解压 AAR
Copy-Item libbox.aar libbox.zip
Expand-Archive libbox.zip libbox_check -Force

# 检查 classes.jar 大小
$jar = Get-Item libbox_check\classes.jar
Write-Host "classes.jar 大小: $($jar.Length) 字节"

if ($jar.Length -lt 100000) {
    Write-Host "❌ classes.jar 太小! 应该 > 500KB" -ForegroundColor Red
} else {
    Write-Host "✅ classes.jar 大小正常" -ForegroundColor Green
}

# 检查 JNI 库
$jniDirs = Get-ChildItem libbox_check\jni
Write-Host "`nJNI 架构:"
foreach ($dir in $jniDirs) {
    Write-Host "  - $($dir.Name)"
}

# 清理
Remove-Item libbox_check -Recurse -Force
Remove-Item libbox.zip
```

使用:
```bash
cd android/app/libs
powershell .\check_libbox.ps1
```

## 你的下一步

1. **选项 A: 使用现成的 AAR** ⭐⭐⭐⭐⭐
   - 从 karing/FlClash 获取
   - 最快最简单

2. **选项 B: 重新编译**
   - 按照上面的方法使用 gomobile
   - 确保 Go 环境正确配置
   - 需要时间和经验

3. **选项 C: 先用临时实现**
   - 注释 libbox 代码
   - 测试基本流程
   - 等有了正确的 AAR 再启用

## 总结

你的 libbox.aar **编译不完整**,缺少 Java 绑定类。

**最快的解决方法**: 从 karing 或 FlClash 项目中获取现成的 libbox.aar,不要自己编译。

编译 sing-box 的 libbox.aar 需要:
- Go 1.21+
- gomobile
- Android NDK
- 正确的环境配置

对于 Flutter 开发者来说,**直接用别人编译好的更省时间**!

