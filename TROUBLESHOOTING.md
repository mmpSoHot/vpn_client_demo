# VPN 客户端问题排查指南

## ❌ 常见问题

### 1. 端口被占用错误

**错误信息**：
```
FATAL[0000] start service: start inbound/mixed[mixed-in]: listen tcp 127.0.0.1:15808: bind: 
Only one usage of each socket address (protocol/network address/port) is normally permitted.
```

**原因**：
- 上次的 sing-box 进程没有正常关闭
- 其他代理软件占用了 15808 端口
- 系统中有多个 sing-box 实例在运行

**解决方案**：

#### 方法 1: 使用应用内重连（推荐）
1. 点击"断开"按钮
2. 等待 2-3 秒
3. 再次点击"连接"按钮

应用会自动清理残留进程。

#### 方法 2: 手动终止进程

**Windows**:
```powershell
# 查看占用端口的进程
netstat -ano | findstr :15808

# 终止 sing-box 进程
taskkill /F /IM sing-box.exe
```

**Linux/macOS**:
```bash
# 查看占用端口的进程
lsof -i :15808

# 终止 sing-box 进程
pkill -9 sing-box
```

#### 方法 3: 更换端口

如果 15808 端口被其他软件长期占用，可以修改配置：

1. 编辑 `lib/utils/singbox_manager.dart`
2. 修改默认端口：
```dart
int mixedPort = 15808,  // 改为其他端口，如 16808
```

3. 同时修改 `lib/pages/home_page.dart` 中的端口检查：
```dart
SystemProxyHelper.isProxySetTo('127.0.0.1', 16808)
```

### 2. VPN 自动断开

**症状**：
- 点击连接后几秒钟自动断开
- 显示"VPN 连接已断开"

**原因**：
- sing-box 启动失败（通常是端口占用）
- 状态监控检测到 sing-box 未运行
- 自动清除系统代理并断开连接

**解决方案**：
1. 按照"端口被占用"的解决方案清理进程
2. 确保没有其他代理软件在运行
3. 重新连接

### 3. 系统代理未生效

**症状**：
- VPN 显示已连接
- 浏览器无法访问外网

**检查步骤**：

1. **检查系统代理设置**：
   ```
   Windows: 设置 → 网络和Internet → 代理
   应该显示:
   - 使用代理服务器: 开启
   - 地址: 127.0.0.1:15808
   ```

2. **检查 sing-box 运行状态**：
   ```powershell
   # Windows
   tasklist | findstr sing-box
   
   # 应该看到 sing-box.exe 进程
   ```

3. **检查端口监听**：
   ```powershell
   netstat -ano | findstr :15808
   
   # 应该看到 127.0.0.1:15808 在 LISTENING 状态
   ```

**解决方案**：
- 如果代理未设置：重新连接 VPN
- 如果 sing-box 未运行：重启应用
- 如果端口未监听：检查 sing-box 配置

### 4. sing-box 配置错误

**错误信息**：
```
ERROR[0000] legacy DNS servers is deprecated
ERROR[0000] geosite database is deprecated
```

**解决方案**：
这些错误已在代码中修复。如果仍然出现：
1. 删除 `config/sing-box-config.json`
2. 重新生成配置
3. 确保使用最新的配置格式

参考: `SINGBOX_VERSION_COMPATIBILITY.md`

### 5. 连接超时

**症状**：
- 点击连接后一直显示"连接中..."
- 最终超时失败

**可能原因**：
1. 节点配置错误
2. 节点服务器不可达
3. 防火墙阻止连接

**解决方案**：
1. 检查节点配置是否正确
2. 尝试更换其他节点
3. 检查防火墙设置
4. 查看 sing-box 日志：
   ```
   控制台应显示 [sing-box] 开头的日志
   ```

## 🔧 调试技巧

### 1. 查看详细日志

在 `lib/utils/singbox_manager.dart` 中已配置日志输出：
```dart
_process!.stdout.transform(utf8.decoder).listen((data) {
  print('[sing-box] $data');
});

_process!.stderr.transform(utf8.decoder).listen((data) {
  print('[sing-box ERROR] $data');
});
```

运行应用时查看控制台输出。

### 2. 手动测试 sing-box

```bash
# 进入项目目录
cd D:\Workspace\flutter\vpn_client_demo

# 手动运行 sing-box
.\sing-box.exe run -c config\sing-box-config.json

# 观察输出，查找错误信息
```

### 3. 测试系统代理

```powershell
# 查看当前代理设置
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer
```

### 4. 网络连接测试

```bash
# 测试代理是否工作
curl -x http://127.0.0.1:15808 https://www.google.com

# 或使用浏览器访问
# 设置代理: 127.0.0.1:15808
# 访问: http://ipinfo.io
```

## 🛠️ 维护命令

### 清理所有 sing-box 进程
```powershell
# Windows
taskkill /F /IM sing-box.exe

# Linux/macOS
pkill -9 sing-box
```

### 清除系统代理
```powershell
# Windows (手动)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "" /f
```

### 重置配置
```bash
# 删除配置文件
rm config/sing-box-config.json

# 重新启动应用，会自动生成新配置
```

## 📊 状态检查清单

连接问题排查清单：

- [ ] sing-box.exe 进程是否运行？
  ```powershell
  tasklist | findstr sing-box
  ```

- [ ] 端口 15808 是否被占用？
  ```powershell
  netstat -ano | findstr :15808
  ```

- [ ] 系统代理是否正确设置？
  ```
  设置 → 网络和Internet → 代理
  ```

- [ ] 配置文件是否存在？
  ```
  检查 config/sing-box-config.json
  ```

- [ ] 节点配置是否有效？
  ```
  查看配置文件中的节点信息
  ```

- [ ] 防火墙是否允许？
  ```
  Windows 防火墙 → 允许应用
  ```

## 🆘 获取帮助

如果以上方法都无法解决问题：

1. **收集日志**：
   - 应用控制台输出
   - sing-box 错误信息
   - 系统代理设置截图

2. **提供信息**：
   - 操作系统版本
   - sing-box 版本
   - 错误发生的步骤

3. **检查文档**：
   - `VPN_CONNECTION_IMPLEMENTATION.md` - 实现细节
   - `SINGBOX_USAGE.md` - sing-box 使用
   - `SYSTEM_PROXY_USAGE.md` - 代理设置

## 🎯 快速解决方案

**最常用的解决步骤**：

1. **完全停止所有进程**
   ```powershell
   taskkill /F /IM sing-box.exe
   ```

2. **等待 2 秒**

3. **重新启动应用**

4. **点击连接**

如果还是不行，重启计算机通常能解决大部分问题。

