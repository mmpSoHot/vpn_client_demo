# Android 规则文件缺失问题修复

## 问题描述

Android VPN 启动时报错：
```
E/VpnService: 启动 VPN 失败
E/VpnService: go.Universe$proxyerror: create service: initialize router: parse rule-set[0]: 
              open /data/user/0/com.example.demo2/files/sing-box/run/geosite-private.srs: no such file or directory
```

**根本原因**：sing-box 需要读取地理位置规则文件（`.srs` 文件）来实现路由规则，但这些文件虽然在 Flutter assets 中，却没有被复制到 Android 应用的内部存储目录中。

## 解决方案

### 1. 文件自动复制机制

在 `MainActivity.kt` 中实现了 `copyAssetsToWorkingDir()` 方法，在应用启动时自动将规则文件从 assets 复制到应用内部存储：

**复制的文件**：
- `geosite-private.srs` - 私有域名规则
- `geosite-cn.srs` - 国内域名规则  
- `geoip-cn.srs` - 国内 IP 规则

**目标路径**：`/data/user/0/com.example.demo2/files/sing-box/run/`

### 2. 增强的日志输出

#### MainActivity 日志
- 列出 assets 目录中的所有文件
- 显示每个文件的复制进度和大小
- 验证复制后的文件是否存在
- 列出工作目录中的所有文件

#### VpnService 日志
- 在启动 VPN 前验证所有必需的规则文件是否存在
- 显示每个文件的大小
- 如果文件缺失，抛出明确的错误信息

### 3. 工作流程

```
App 启动
  ↓
MainActivity.onCreate()
  ↓
setupLibbox()
  ↓
1. 创建目录结构
   - /files/sing-box/
   - /files/sing-box/run/
  ↓
2. copyAssetsToWorkingDir()
   - 从 assets/srss/ 复制 .srs 文件
   - 到 /files/sing-box/run/
  ↓
3. Libbox.setup()
   - 设置 workingPath
  ↓
VPN 启动时
  ↓
VpnService.startVpn()
  ↓
1. 验证规则文件存在
2. 创建 sing-box 实例
3. 启动 VPN
```

## 如何验证修复

重新运行应用后，查看 logcat 输出：

### 成功的日志应该包含：

```
D/MainActivity: 🚀 MainActivity.onCreate() 开始
D/MainActivity: 🔧 开始初始化 Libbox...
D/MainActivity: 📦 开始复制 3 个规则文件到: /data/user/0/com.example.demo2/files/sing-box/run
D/MainActivity: 📁 assets/srss 目录中的文件: [列出所有文件]
D/MainActivity:    处理文件: geosite-private.srs
D/MainActivity:       原文件大小: XXXXX 字节
D/MainActivity:       已复制: XXXXX 字节
D/MainActivity:    ✅ 复制成功: /data/user/0/com.example.demo2/files/sing-box/run/geosite-private.srs (XXXXX 字节)
D/MainActivity:    [重复其他文件...]
D/MainActivity: 📁 工作目录中的文件:
D/MainActivity:    - geosite-private.srs (XXXXX 字节)
D/MainActivity:    - geosite-cn.srs (XXXXX 字节)
D/MainActivity:    - geoip-cn.srs (XXXXX 字节)
D/MainActivity: ✅ Libbox 初始化成功
```

### VPN 启动时的日志：

```
D/VpnService: 启动 VPN...
D/VpnService: 🔍 检查规则文件...
D/VpnService:    工作目录: /data/user/0/com.example.demo2/files/sing-box/run
D/VpnService:    ✅ geosite-private.srs (XXXXX 字节)
D/VpnService:    ✅ geosite-cn.srs (XXXXX 字节)
D/VpnService:    ✅ geoip-cn.srs (XXXXX 字节)
D/VpnService: 📦 创建 sing-box 实例...
D/VpnService: 🚀 启动 sing-box...
D/VpnService: ✅ VPN 启动成功
```

## 故障排除

### 如果仍然报错文件不存在：

1. **检查 pubspec.yaml** 
   确保 assets 配置正确：
   ```yaml
   flutter:
     assets:
       - srss/
   ```

2. **清理并重新构建**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk
   ```

3. **检查 MainActivity 日志**
   - assets 目录是否能列出文件？
   - 文件复制是否成功？
   - 是否有权限错误？

4. **手动验证文件**
   使用 adb shell 进入设备：
   ```bash
   adb shell
   cd /data/data/com.example.demo2/files/sing-box/run
   ls -lh
   ```

### 如果 assets 目录列不出文件：

可能是 Flutter 打包问题，尝试：
1. 删除 `build/` 目录
2. 运行 `flutter pub get`
3. 重新构建

## 相关文件

- `android/app/src/main/kotlin/com/example/demo2/MainActivity.kt` - 文件复制逻辑
- `android/app/src/main/kotlin/com/example/demo2/VpnService.kt` - 文件验证逻辑
- `lib/utils/node_config_converter.dart` - sing-box 配置生成
- `pubspec.yaml` - assets 配置
- `srss/` - 规则文件目录

## 注意事项

1. **首次启动**：规则文件复制在 `MainActivity.onCreate()` 中进行，只在应用首次启动或重新安装后执行一次
2. **文件更新**：如果需要更新规则文件，当前会覆盖旧文件（每次启动都复制）
3. **存储空间**：3个 `.srs` 文件总共约占用几 MB 空间
4. **性能影响**：文件复制在主线程进行，但速度很快（通常 < 100ms）

## 后续优化建议

1. **异步复制**：将文件复制移到后台线程，避免阻塞主线程
2. **增量更新**：只在文件不存在或版本更新时才复制
3. **压缩优化**：考虑压缩 `.srs` 文件以减小 APK 体积
4. **远程下载**：考虑从服务器下载最新规则文件，而不是打包在 APK 中

