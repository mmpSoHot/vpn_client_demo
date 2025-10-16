@echo off
echo ========================================
echo Android VPN 测试脚本
echo ========================================
echo.

echo [1/5] 清理旧的构建...
flutter clean

echo.
echo [2/5] 获取依赖...
flutter pub get

echo.
echo [3/5] 编译 APK...
flutter build apk

echo.
echo [4/5] 安装到设备...
flutter install

echo.
echo [5/5] 启动应用并查看日志...
echo 请在手机上：
echo   1. 登录应用（用户名: admin, 密码: 123456）
echo   2. 选择一个节点
echo   3. 点击连接
echo.
echo 正在监听日志...
echo ========================================
echo.

adb logcat -c
adb logcat -s flutter:I VpnService:D sing-box:I PlatformInterface:D

pause

