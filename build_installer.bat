@echo off
chcp 65001 >nul
echo ========================================
echo VPN Client Demo - Windows 安装包构建
echo ========================================
echo.

REM 检查 Inno Setup 是否安装
set INNO_SETUP="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist %INNO_SETUP% (
    echo ❌ 未找到 Inno Setup
    echo 请从以下地址下载并安装:
    echo https://jrsoftware.org/isdl.php
    echo.
    pause
    exit /b 1
)

REM 步骤 1: 清理旧构建
echo [1/4] 清理旧构建...
call flutter clean
echo ✅ 清理完成
echo.

REM 步骤 2: 构建 Release 版本
echo [2/4] 构建 Windows Release 版本...
call flutter build windows --release
if errorlevel 1 (
    echo ❌ 构建失败
    pause
    exit /b 1
)
echo ✅ 构建完成
echo.

REM 步骤 3: 验证文件
echo [3/4] 验证文件...
if not exist "build\windows\x64\runner\Release\demo2.exe" (
    echo ❌ 未找到 demo2.exe
    pause
    exit /b 1
)
echo ✅ demo2.exe 存在

if not exist "build\windows\x64\runner\Release\sing-box.exe" (
    echo ❌ 未找到 sing-box.exe
    echo 正在手动复制...
    copy sing-box.exe build\windows\x64\runner\Release\
)
echo ✅ sing-box.exe 存在

if not exist "build\windows\x64\runner\Release\data\flutter_assets\srss" (
    echo ⚠️  警告: srss 规则文件目录未找到
) else (
    echo ✅ srss 规则文件存在
)
echo.

REM 步骤 4: 创建安装包
echo [4/4] 创建安装包...
if not exist "dist" mkdir dist
%INNO_SETUP% windows\packaging\exe\setup.iss
if errorlevel 1 (
    echo ❌ 创建安装包失败
    pause
    exit /b 1
)
echo.

echo ========================================
echo ✅ 安装包创建成功！
echo ========================================
echo 输出位置: dist\VPN_Client_Demo_Setup_1.0.0.exe
echo.
echo 提示: 可以直接运行此安装包进行安装测试
echo.
pause

