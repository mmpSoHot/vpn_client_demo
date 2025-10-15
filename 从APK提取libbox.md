# 从 APK 提取 libbox 文件

## ⚠️ 重要说明

从 APK 中**只能提取 .so 文件**(JNI 库),**不能直接得到 .aar**。

但我们可以尝试**手动构建 AAR**!

## 方法 1: 提取 .so 文件并手动打包 AAR

### 步骤 1: 下载 sing-box APK

1. 访问官方 Releases:
   ```
   https://github.com/SagerNet/sing-box-for-android/releases
   ```

2. 下载最新的 APK (选择 universal 版本):
   ```
   例如: SFA-2.x.x-universal.apk
   ```

### 步骤 2: 提取 APK 内容

在 Windows PowerShell 中:

```powershell
# 1. 重命名 APK 为 ZIP
Copy-Item SFA-2.x.x-universal.apk SFA.zip

# 2. 解压
Expand-Archive SFA.zip SFA_extracted -Force

# 3. 查看结构
cd SFA_extracted
dir

# 4. 查找 .so 文件
dir lib -Recurse

# 应该看到:
# lib/arm64-v8a/libbox.so
# lib/armeabi-v7a/libbox.so
# lib/x86/libbox.so
# lib/x86_64/libbox.so
```

### 步骤 3: 提取 classes.dex 并转换

```powershell
# APK 中的 classes.dex 包含 Java 代码
# 需要转换为 .jar

# 1. 下载 dex2jar
# https://github.com/pxb1988/dex2jar/releases

# 2. 转换
d2j-dex2jar.bat classes.dex
# 生成 classes-dex2jar.jar
```

### 步骤 4: 手动构建 AAR

AAR 文件就是一个 ZIP,包含特定结构:

```
libbox.aar (实际是 ZIP)
├── AndroidManifest.xml
├── classes.jar
├── R.txt
├── res/
└── jni/
    ├── arm64-v8a/libbox.so
    ├── armeabi-v7a/libbox.so
    ├── x86/libbox.so
    └── x86_64/libbox.so
```

创建 AAR:

```powershell
# 1. 创建目录结构
mkdir libbox_aar
cd libbox_aar

mkdir jni
mkdir jni\arm64-v8a
mkdir jni\armeabi-v7a
mkdir jni\x86
mkdir jni\x86_64

# 2. 复制 .so 文件
copy ..\SFA_extracted\lib\arm64-v8a\libbox.so jni\arm64-v8a\
copy ..\SFA_extracted\lib\armeabi-v7a\libbox.so jni\armeabi-v7a\
copy ..\SFA_extracted\lib\x86\libbox.so jni\x86\
copy ..\SFA_extracted\lib\x86_64\libbox.so jni\x86_64\

# 3. 复制转换后的 classes.jar
copy ..\classes-dex2jar.jar classes.jar

# 4. 创建 AndroidManifest.xml
@"
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="libbox">
    <uses-sdk android:minSdkVersion="21" />
</manifest>
"@ | Out-File -Encoding UTF8 AndroidManifest.xml

# 5. 创建空的 R.txt
New-Item R.txt

# 6. 打包为 ZIP
Compress-Archive -Path * -DestinationPath libbox.zip

# 7. 重命名为 AAR
Move-Item libbox.zip libbox.aar -Force
```

## 方法 2: 使用 jadx 反编译后重新编译 (复杂)

这个方法太复杂,不推荐。

## 方法 3: 最简单但不完美的方法

**直接复制你当前的 libbox.aar,然后替换其中的 .so 文件:**

```powershell
# 1. 解压你当前的 libbox.aar
cd D:\Workspace\flutter\vpn_client_demo\android\app\libs
Copy-Item libbox.aar libbox_old.zip
Expand-Archive libbox_old.zip libbox_rebuild -Force

# 2. 下载并解压 sing-box APK
# (假设已下载到当前目录)
Copy-Item SFA-2.x.x-universal.apk SFA.zip
Expand-Archive SFA.zip SFA_extracted -Force

# 3. 替换 .so 文件
copy SFA_extracted\lib\arm64-v8a\libbox.so libbox_rebuild\jni\arm64-v8a\
copy SFA_extracted\lib\armeabi-v7a\libbox.so libbox_rebuild\jni\armeabi-v7a\
copy SFA_extracted\lib\x86\libbox.so libbox_rebuild\jni\x86\
copy SFA_extracted\lib\x86_64\libbox.so libbox_rebuild\jni\x86_64\

# 4. 重新打包
cd libbox_rebuild
Compress-Archive -Path * -DestinationPath ..\libbox_new.aar -Force

# 5. 替换旧的 AAR
cd ..
Move-Item libbox_new.aar libbox.aar -Force
```

## ⚠️ 问题与限制

### 1. classes.jar 的问题

从 APK 提取的 classes.dex 转换后的 jar **可能不包含完整的 libbox 接口类**,因为:
- APK 中的代码可能被混淆
- 可能只包含应用代码,不包含库的公共接口

### 2. 版本兼容性

即使提取成功,也可能因为版本不匹配导致接口不同。

### 3. 法律问题

从别人的 APK 提取代码可能有版权问题。

## ✅ 我的建议

**从 APK 提取不是好办法**,原因:
1. classes.jar 可能不完整或被混淆
2. 接口定义可能缺失
3. 费时费力且不保证成功

### 更好的选择:

#### 选择 A: 编译 sing-box-for-android (推荐⭐⭐⭐⭐⭐)

```bash
# 这是获得完整 AAR 的唯一可靠方法
git clone https://github.com/SagerNet/sing-box-for-android
cd sing-box-for-android
./gradlew :libbox:assembleRelease
```

**优点**:
- ✅ 获得完整的 AAR
- ✅ 包含所有接口定义
- ✅ 版本一致
- ✅ 合法

**缺点**:
- ❌ 需要配置 Android 开发环境
- ❌ 需要时间 (首次编译可能 10-30 分钟)

#### 选择 B: 使用临时实现 (当前最快⭐⭐⭐⭐⭐)

**我强烈推荐这个**:
- ✅ 2分钟就能运行
- ✅ 测试所有功能
- ✅ 不影响开发进度
- ⏰ 等有空了再处理 libbox

## 快速对比

| 方法 | 时间 | 成功率 | 推荐度 |
|------|------|--------|--------|
| 从 APK 提取 | 2-3小时 | 30% | ⭐ |
| 编译 sing-box-for-android | 30-60分钟 | 95% | ⭐⭐⭐⭐⭐ |
| 使用临时实现 | 2分钟 | 100% | ⭐⭐⭐⭐⭐ |

## 我的推荐

**现在**: 使用临时实现,让应用先跑起来

**以后**: 抽空编译 sing-box-for-android 获取完整 AAR

**不推荐**: 从 APK 提取 (费时费力成功率低)

---

需要我帮你:
1. 切换到临时实现? (2分钟)
2. 写一个自动编译 sing-box-for-android 的脚本? (10分钟)
3. 尝试从 APK 提取? (不保证成功)

你选哪个?

