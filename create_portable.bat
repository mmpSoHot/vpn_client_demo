@echo off
chcp 65001 >nul
echo ========================================
echo 创建便携版（绿色版）
echo ========================================
echo.

REM 检查构建是否存在
if not exist "build\windows\x64\runner\Release\demo2.exe" (
    echo ❌ 未找到构建文件
    echo 请先运行: flutter build windows --release
    pause
    exit /b 1
)

REM 创建输出目录
set OUTPUT_DIR=dist\VPN_Client_Demo_Portable_v1.0.0
if exist "%OUTPUT_DIR%" rmdir /s /q "%OUTPUT_DIR%"
mkdir "%OUTPUT_DIR%"

echo [1/3] 复制文件...
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "%OUTPUT_DIR%\"
echo ✅ 文件复制完成
echo.

echo [2/3] 创建说明文件...
(
echo VPN Client Demo - 便携版
echo ================================
echo.
echo 使用说明:
echo 1. 双击 demo2.exe 启动应用
echo 2. 首次使用需要管理员权限（用于设置系统代理）
echo 3. 所有数据保存在用户目录: %%USERPROFILE%%\.vpn_client_demo\
echo.
echo 文件说明:
echo - demo2.exe: 主程序
echo - sing-box.exe: VPN 核心组件
echo - data\flutter_assets\srss\: 路由规则文件
echo.
echo 卸载:
echo 直接删除此文件夹即可，用户数据在 %%USERPROFILE%%\.vpn_client_demo\
echo.
echo 系统要求:
echo - Windows 10 或更高版本
echo - 需要管理员权限（首次运行）
) > "%OUTPUT_DIR%\使用说明.txt"
echo ✅ 说明文件创建完成
echo.

echo [3/3] 创建启动器（以管理员身份运行）...
(
echo @echo off
echo echo 正在以管理员身份启动 VPN Client Demo...
echo powershell -Command "Start-Process '%%~dp0demo2.exe' -Verb RunAs"
) > "%OUTPUT_DIR%\以管理员身份运行.bat"
echo ✅ 启动器创建完成
echo.

echo ========================================
echo ✅ 便携版创建成功！
echo ========================================
echo 输出位置: %OUTPUT_DIR%
echo.
echo 可以直接将此文件夹:
echo 1. 压缩成 zip 分发
echo 2. 复制到其他电脑使用
echo 3. 上传到网盘分享
echo.

REM 计算文件夹大小
for /f "tokens=3" %%a in ('dir "%OUTPUT_DIR%" /s /-c ^| findstr /C:"个文件"') do set SIZE=%%a
echo 文件夹大小: %SIZE% 字节
echo.

REM 询问是否压缩
set /p COMPRESS="是否创建 ZIP 压缩包? (y/n): "
if /i "%COMPRESS%"=="y" (
    echo.
    echo 正在压缩...
    powershell Compress-Archive -Path "%OUTPUT_DIR%\*" -DestinationPath "dist\VPN_Client_Demo_Portable_v1.0.0.zip" -Force
    echo ✅ ZIP 文件已创建: dist\VPN_Client_Demo_Portable_v1.0.0.zip
)

echo.
pause

