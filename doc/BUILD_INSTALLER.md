# 构建 Windows 安装包指南

## 前置要求

### 1. 安装 Inno Setup

**下载地址**：https://jrsoftware.org/isdl.php

**安装步骤**：
1. 下载 Inno Setup 6.x (Unicode 版本)
2. 运行安装程序
3. 默认安装到 `C:\Program Files (x86)\Inno Setup 6\`

### 2. 确保必需文件存在

检查以下文件是否在项目根目录：
- ✅ `sing-box.exe` (约 37.8 MB)
- ✅ `srss/` 目录及规则文件
- ✅ `windows/packaging/exe/setup.iss`

## 快速构建（推荐）

### 方法 1：使用自动化脚本

```batch
# 直接运行（会自动执行所有步骤）
build_installer.bat
```

脚本会自动：
1. ✅ 清理旧构建
2. ✅ 构建 Release 版本
3. ✅ 验证文件完整性
4. ✅ 创建安装包
5. ✅ 输出到 `dist/` 目录

### 方法 2：手动步骤

如果自动脚本有问题，可以手动执行：

```batch
# 1. 清理
flutter clean

# 2. 构建
flutter build windows --release

# 3. 验证（可选）
dir build\windows\x64\runner\Release\sing-box.exe
dir build\windows\x64\runner\Release\data\flutter_assets\srss\

# 4. 创建安装包
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\packaging\exe\setup.iss
```

## 输出文件

### 安装包位置
```
dist/VPN_Client_Demo_Setup_1.0.0.exe
```

### 安装包大小
约 50-60 MB（包含所有依赖）

## 安装包内容

安装后会在用户选择的目录创建：

```
C:\Program Files\VPN Client Demo\
├── demo2.exe                    # 主程序
├── sing-box.exe                 # VPN 核心
├── flutter_windows.dll          # Flutter 引擎
├── *.dll                        # 其他依赖
├── config\                      # 配置目录（运行时创建）
└── data\
    └── flutter_assets\
        └── srss\                # 规则文件
            ├── geosite-cn.srs
            ├── geoip-cn.srs
            └── geosite-private.srs
```

## 安装包功能

### 基本功能
- ✅ 自动安装到 Program Files
- ✅ 创建开始菜单快捷方式
- ✅ 可选创建桌面图标
- ✅ 可选开机自动启动
- ✅ 完整的卸载功能

### 高级功能
- ✅ 需要管理员权限（用于系统代理设置）
- ✅ 支持静默安装：`/SILENT` 或 `/VERYSILENT`
- ✅ 支持自定义安装目录
- ✅ 中英文界面支持

## 测试安装包

### 1. 安装测试

```batch
# 运行安装包
dist\VPN_Client_Demo_Setup_1.0.0.exe

# 按照向导完成安装
```

### 2. 功能测试

安装后测试：
- ✅ 应用能否正常启动
- ✅ sing-box.exe 是否在程序目录
- ✅ 规则文件是否加载成功
- ✅ VPN 连接是否正常
- ✅ 系统代理设置是否工作

### 3. 卸载测试

```
控制面板 → 程序和功能 → VPN Client Demo → 卸载
```

检查：
- ✅ 程序文件是否删除
- ✅ 开始菜单项是否删除
- ✅ 桌面图标是否删除（如果创建了）
- ✅ 自动启动任务是否删除

## 自定义配置

### 修改版本号

编辑 `windows/packaging/exe/setup.iss`：
```iss
#define MyAppVersion "1.0.0"  ; 修改这里
```

### 修改应用名称

```iss
#define MyAppName "VPN Client Demo"  ; 修改这里
```

### 修改安装位置

```iss
DefaultDirName={autopf}\{#MyAppName}  ; {autopf} = C:\Program Files
; 或
DefaultDirName={localappdata}\{#MyAppName}  ; 安装到用户目录（不需要管理员）
```

### 添加额外文件

```iss
[Files]
; 所有文件
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

; 添加额外文件（可选）
Source: "..\..\..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\doc\*"; DestDir: "{app}\doc"; Flags: ignoreversion recursesubdirs
```

## 常见问题

### Q1: Inno Setup 编译失败

**错误**：`Unable to open file`

**解决**：
1. 检查路径是否正确
2. 检查文件是否存在
3. 使用绝对路径测试

### Q2: 安装包太大

**优化**：
1. 移除不需要的 DLL
2. 压缩资源文件
3. 使用 `lzma2` 压缩算法

```iss
Compression=lzma2/ultra64
```

### Q3: 需要管理员权限

**原因**：
- 设置系统代理需要管理员权限
- 安装到 Program Files 需要管理员权限

**如果不需要管理员**：
```iss
PrivilegesRequired=lowest
DefaultDirName={localappdata}\{#MyAppName}
```

但这样无法设置系统代理。

### Q4: 安装后运行报错

**检查**：
1. sing-box.exe 是否在应用目录
2. 规则文件是否在 `data/flutter_assets/srss/`
3. 是否有 Visual C++ 运行库

**安装 VC++ 运行库**：
下载并安装 Microsoft Visual C++ Redistributable

## 高级功能

### 静默安装

```batch
# 完全静默
VPN_Client_Demo_Setup_1.0.0.exe /VERYSILENT

# 静默但显示进度
VPN_Client_Demo_Setup_1.0.0.exe /SILENT

# 指定安装目录
VPN_Client_Demo_Setup_1.0.0.exe /DIR="D:\VPN_Client_Demo"

# 不创建桌面图标
VPN_Client_Demo_Setup_1.0.0.exe /TASKS="!desktopicon"
```

### 自动更新支持

可以添加版本检查和自动更新功能：
```iss
[Code]
function InitializeSetup(): Boolean;
var
  InstalledVersion: String;
  CurrentVersion: String;
begin
  CurrentVersion := '{#MyAppVersion}';
  
  // 检查是否已安装
  if RegQueryStringValue(HKLM, 
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1',
    'DisplayVersion', InstalledVersion) then
  begin
    // 比较版本...
  end;
  
  Result := True;
end;
```

## 分发

### 上传到 GitHub Release

```bash
# 创建 Release
gh release create v1.0.0 dist/VPN_Client_Demo_Setup_1.0.0.exe

# 或在 GitHub 网页上传
```

### 用户下载安装

1. 用户下载 `VPN_Client_Demo_Setup_1.0.0.exe`
2. 双击运行
3. 按照向导完成安装
4. 启动应用

## 参考项目

- **FlClash**: 使用类似的 Inno Setup 打包方式
- **v2rayN**: 也使用 Inno Setup
- **karing**: 使用 Inno Setup + flutter_distributor

## 相关文件

- `windows/packaging/exe/setup.iss` - Inno Setup 脚本
- `build_installer.bat` - 自动化构建脚本
- `windows/CMakeLists.txt` - CMake 配置（自动复制 sing-box.exe）

## 总结

✅ **一键打包**：
```batch
build_installer.bat
```

✅ **输出**：
```
dist/VPN_Client_Demo_Setup_1.0.0.exe
```

✅ **完全参考 FlClash 的专业打包方式！**

