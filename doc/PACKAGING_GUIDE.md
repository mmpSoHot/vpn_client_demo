# 打包指南

## Windows 打包配置（参考 FlClash）

### 文件结构

**开发环境**：
```
vpn_client_demo/
├── lib/
├── windows/
├── sing-box.exe          # 开发时放这里
├── srss/                 # 规则文件
└── config/
```

**发布后**：
```
build/windows/x64/runner/Release/
├── demo2.exe             # 主程序
├── sing-box.exe          # 自动复制（CMake）
├── data/
│   └── flutter_assets/
│       └── srss/         # 规则文件（自动打包）
│           ├── geosite-cn.srs
│           ├── geoip-cn.srs
│           └── ...
└── ...其他 DLL
```

### CMake 配置

已在 `windows/CMakeLists.txt` 中添加：

```cmake
# 安装 sing-box.exe 核心文件（参考 FlClash）
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../sing-box.exe")
  install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/../sing-box.exe" 
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
  message(STATUS "将安装 sing-box.exe 到输出目录")
else()
  message(WARNING "未找到 sing-box.exe，请确保它在项目根目录")
endif()
```

### 路径查找逻辑

```dart
// lib/utils/singbox_manager.dart
static String getSingboxPath() {
  // 1. 开发环境：从项目根目录
  final devPath = path.join(Directory.current.path, 'sing-box.exe');
  if (File(devPath).existsSync()) {
    return devPath;
  }

  // 2. 发布环境：从主程序同级目录（与 FlClash 一致）
  final exeDir = path.dirname(Platform.resolvedExecutable);
  final bundlePath = path.join(exeDir, 'sing-box.exe');
  if (File(bundlePath).existsSync()) {
    return bundlePath;
  }

  throw Exception('sing-box.exe 未找到！');
}
```

## 打包步骤

### 方法 1：使用 Flutter 命令行（推荐）

```bash
# 1. 确保 sing-box.exe 在项目根目录
# 2. 构建 Windows 应用
flutter build windows --release

# 3. 输出位置
# build/windows/x64/runner/Release/
```

构建后，sing-box.exe 会自动复制到输出目录（由 CMake 处理）。

### 方法 2：使用 Visual Studio

```bash
# 1. 生成 Visual Studio 项目
flutter build windows --release

# 2. 打开 build/windows/demo2.sln

# 3. 在 Visual Studio 中选择 Release 配置

# 4. 构建 → 安装

# 5. sing-box.exe 自动安装到输出目录
```

### 方法 3：手动打包

如果 CMake 安装不工作，可以手动复制：

```bash
# 1. 构建应用
flutter build windows --release

# 2. 手动复制 sing-box.exe
copy sing-box.exe build\windows\x64\runner\Release\

# 3. 验证
dir build\windows\x64\runner\Release\
```

## 验证打包结果

### 检查文件是否存在

```bash
# 查看输出目录
dir build\windows\x64\runner\Release\

# 应该看到：
# demo2.exe
# sing-box.exe          ← 核心文件
# flutter_windows.dll
# data\flutter_assets\srss\  ← 规则文件
```

### 测试运行

```bash
# 进入输出目录
cd build\windows\x64\runner\Release\

# 运行应用
demo2.exe

# 应用应该能：
# 1. 自动找到 sing-box.exe
# 2. 加载规则文件
# 3. 正常连接 VPN
```

## 资源文件打包

### srss 规则文件

已在 `pubspec.yaml` 中配置：
```yaml
flutter:
  assets:
    - srss/
```

打包后位置：
```
build/windows/x64/runner/Release/data/flutter_assets/srss/
```

代码中访问：
```dart
// lib/utils/node_config_converter.dart
final devPath = path.join(Directory.current.path, 'srss');
final bundlePath = path.join(exeDir, 'data', 'flutter_assets', 'srss');
```

## 分发包准备

### 最小分发包

```
VPN_Client_Demo/
├── demo2.exe
├── sing-box.exe
├── flutter_windows.dll
├── data/
│   ├── icudtl.dat
│   └── flutter_assets/
│       └── srss/
│           ├── geosite-cn.srs
│           ├── geoip-cn.srs
│           └── geosite-private.srs
└── msvcp140.dll (可能需要)
```

### 使用 Inno Setup 打包（参考 FlClash）

1. **安装 Inno Setup**：
   - 下载：https://jrsoftware.org/isdl.php

2. **创建安装脚本**：
   ```iss
   [Setup]
   AppName=VPN Client Demo
   AppVersion=1.0.0
   DefaultDirName={pf}\VPN_Client_Demo
   DefaultGroupName=VPN Client Demo
   OutputBaseFilename=VPN_Client_Demo_Setup
   
   [Files]
   Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs
   
   [Icons]
   Name: "{group}\VPN Client Demo"; Filename: "{app}\demo2.exe"
   ```

3. **编译安装包**：
   ```bash
   iscc setup.iss
   ```

## 与 FlClash 的对比

### FlClash
```
FlClash/
├── FlClash.exe           # 主程序
├── FlClashCore.exe       # Clash 核心（Go）
├── FlClashHelperService.exe  # VPN 服务
├── EnableLoopback.exe    # UWP 工具
└── data/flutter_assets/
```

### 我们的项目
```
demo2/
├── demo2.exe             # 主程序
├── sing-box.exe          # sing-box 核心
└── data/flutter_assets/
    └── srss/             # 规则文件
```

**更简洁！** ✅

## 常见问题

### Q1: CMake 没有复制 sing-box.exe

**解决方案**：
```bash
# 重新运行 flutter build
flutter clean
flutter build windows --release
```

### Q2: 找不到 sing-box.exe

**检查**：
1. 项目根目录是否有 sing-box.exe
2. CMakeLists.txt 中的路径是否正确
3. 查看构建日志是否有警告

**手动复制**：
```bash
copy sing-box.exe build\windows\x64\runner\Release\
```

### Q3: 运行时找不到规则文件

**检查**：
1. `pubspec.yaml` 中是否添加了 `srss/` assets
2. 构建日志是否有资源打包信息
3. `data/flutter_assets/srss/` 目录是否存在

### Q4: 发布后路径不对

**调试**：
```dart
// 打印路径信息
print('可执行文件: ${Platform.resolvedExecutable}');
print('可执行目录: ${path.dirname(Platform.resolvedExecutable)}');
print('当前目录: ${Directory.current.path}');
```

## 未来改进

### 1. 自动化打包脚本

创建 `build_windows.bat`：
```batch
@echo off
echo 开始构建 Windows 应用...

REM 清理旧构建
flutter clean

REM 构建 Release 版本
flutter build windows --release

REM 验证文件
if exist build\windows\x64\runner\Release\sing-box.exe (
    echo ✅ sing-box.exe 已成功打包
) else (
    echo ❌ sing-box.exe 未找到，手动复制...
    copy sing-box.exe build\windows\x64\runner\Release\
)

echo 构建完成！
echo 输出位置: build\windows\x64\runner\Release\
pause
```

### 2. 使用 flutter_distributor

```yaml
# distribute_options.yaml
output: dist/
releases:
  - name: windows
    jobs:
      - name: windows-exe
        package:
          platform: windows
          target: exe
```

### 3. CI/CD 自动化

```yaml
# .github/workflows/build.yml
- name: Build Windows
  run: |
    flutter build windows --release
    # 自动打包并上传到 Release
```

## 相关文件

- `windows/CMakeLists.txt` - CMake 构建配置
- `lib/utils/singbox_manager.dart` - 路径查找逻辑
- `pubspec.yaml` - 资源配置
- `参考项目/FlClash-main/windows/CMakeLists.txt` - FlClash 参考

## 总结

✅ **已完成**：
1. CMakeLists.txt 配置 sing-box.exe 自动安装
2. 路径查找逻辑与 FlClash 一致
3. 规则文件自动打包到 flutter_assets

✅ **使用方法**：
1. 确保 sing-box.exe 在项目根目录
2. 运行 `flutter build windows --release`
3. 输出在 `build/windows/x64/runner/Release/`

✅ **完全符合 FlClash 的最佳实践！**

