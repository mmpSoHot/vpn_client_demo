# Sing-box 集成实现总结

## ✅ 已完成功能

### 1. 节点配置转换器 (`lib/utils/node_config_converter.dart`)

支持将以下协议的节点URL转换为 Sing-box 配置：

#### ✅ Hysteria2
- 示例: `hysteria2://uuid@server:port?sni=xxx&security=tls&insecure=1#name`
- 生成配置包含: server, port, password, TLS设置

#### ✅ VMess  
- 示例: `vmess://base64(json配置)`
- 支持: TCP/WebSocket/gRPC 传输
- 支持: TLS 加密
- 生成配置包含: server, port, uuid, alter_id, security, transport, tls

#### ✅ VLESS
- 示例: `vless://uuid@server:port?params#name`
- 支持: XTLS-Vision flow
- 支持: TLS/Reality 加密
- 生成配置包含: server, port, uuid, flow, tls, transport

### 2. Sing-box 管理器 (`lib/utils/singbox_manager.dart`)

**核心功能**:
- ✅ 自动查找 `sing-box.exe` 路径
  - 优先从项目根目录查找（开发环境）
  - 其次从 exe 同级目录查找（发布环境）
  
- ✅ 配置文件管理
  - 自动创建 `config/` 目录
  - 生成 `sing-box-config.json` 配置文件
  
- ✅ 进程管理
  - 启动 sing-box 进程
  - 停止 sing-box 进程
  - 重启 sing-box 进程
  - 检查运行状态
  - 监听进程输出（stdout/stderr）

### 3. 节点选择页面集成

**点击节点自动执行**:
1. 生成该节点的 sing-box 配置
2. 如果已有连接，先停止旧连接
3. 启动新的 sing-box 进程
4. 显示连接结果提示
5. 更新首页选中节点显示

### 4. 测试页面 (`lib/pages/singbox_test_page.dart`)

提供独立的测试界面：
- 查看 sing-box.exe 和配置文件路径
- 手动生成配置
- 手动启动/停止/重启
- 查看运行状态

## 🎯 使用方式

### 用户视角

1. **登录并选择订阅**
   ```
   登录 → 购买/激活订阅 → 首页显示订阅信息
   ```

2. **选择并连接节点**
   ```
   首页 → 点击"选择节点" → 从列表选择节点 → 自动连接
   ```

3. **系统代理配置**
   ```
   Windows设置 → 网络和Internet → 代理
   手动设置: 127.0.0.1:15808
   ```

### 开发者视角

```dart
// 1. 从节点URL创建节点对象
final node = NodeModel.fromSubscriptionLine(nodeUrl);

// 2. 生成配置
await SingboxManager.generateConfigFromNode(
  node: node,
  mixedPort: 15808,
  enableTun: false,
);

// 3. 启动
await SingboxManager.start();

// 4. 停止
await SingboxManager.stop();
```

## 📁 文件说明

### 新增文件

| 文件路径 | 说明 |
|---------|------|
| `lib/utils/node_config_converter.dart` | 节点配置转换器 |
| `lib/utils/singbox_manager.dart` | Sing-box 进程管理 |
| `lib/pages/singbox_test_page.dart` | 测试页面 |
| `SINGBOX_USAGE.md` | 使用文档 |
| `IMPLEMENTATION_SUMMARY.md` | 实现总结（本文件） |

### 修改文件

| 文件路径 | 修改内容 |
|---------|---------|
| `lib/models/node_model.dart` | 修复VMess节点解析 |
| `lib/pages/node_selection_page.dart` | 保存NodeModel对象，点击时生成配置 |
| `lib/pages/home_page.dart` | 添加测试入口 |
| `.gitignore` | 忽略配置文件和exe |

## 🔄 工作流程

```
用户操作
  ↓
点击节点
  ↓
[NodeSelectionPage]
  │
  ├─→ 获取 NodeModel
  │
  ├─→ [NodeConfigConverter]
  │     └─→ 解析节点URL参数
  │     └─→ 生成 Sing-box 配置JSON
  │
  ├─→ [SingboxManager]
  │     ├─→ 保存配置到文件
  │     ├─→ 停止旧进程（如果有）
  │     └─→ 启动 sing-box.exe
  │           └─→ 参数: run -c config/sing-box-config.json
  │
  └─→ 显示连接结果
        └─→ 成功: ✅ 已连接
        └─→ 失败: ❌ 启动失败
```

## 📊 配置示例

### 生成的 Sing-box 配置结构

```json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {"tag": "google", "server": "8.8.8.8", "type": "udp"},
      {"tag": "local", "server": "223.5.5.5", "type": "udp"}
    ],
    "final": "google"
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 15808,
      "sniff": true
    }
  ],
  "outbounds": [
    {
      // 根据节点类型动态生成
      "type": "hysteria2|vmess|vless",
      "tag": "节点名称",
      ...
    },
    {"type": "direct", "tag": "direct"},
    {"type": "block", "tag": "block"}
  ],
  "route": {
    "default_domain_resolver": {
      "server": "google",
      "strategy": "prefer_ipv4"
    },
    "rules": [
      {"action": "sniff"},
      {"protocol": "dns", "action": "hijack-dns"},
      {"ip_is_private": true, "outbound": "direct"}
    ],
    "final": "节点tag",
    "auto_detect_interface": true
  }
}
```

## 🎨 UI 交互

### 节点选择流程

1. **打开节点选择**
   - 从底部滑出 BottomSheet
   - 显示加载动画

2. **加载节点列表**
   - 调用API获取订阅信息
   - 解码Base64订阅数据
   - 解析节点URL
   - 显示节点列表（带国旗、协议、倍率标签）

3. **点击节点**
   - 显示 "正在配置节点..." 提示
   - 后台生成配置并启动 sing-box
   - 成功后显示 "✅ 已连接到：xxx"
   - 自动关闭 BottomSheet

### 状态提示

- 🟢 **成功**: 绿色 SnackBar，持续2秒
- 🔴 **失败**: 红色 SnackBar，持续2-3秒
- 🔵 **处理中**: 蓝色 SnackBar，持续2秒

## 🛠️ 技术细节

### Sing-box 进程管理

```dart
// 进程启动模式
Process.start(
  singboxPath,
  ['run', '-c', configPath],
  mode: ProcessStartMode.detached,  // 分离模式，不阻塞主进程
);

// 进程输出监听
_process!.stdout.transform(utf8.decoder).listen((data) {
  print('[sing-box] $data');
});

// 进程停止
_process!.kill(ProcessSignal.sigterm);  // 优雅停止
await _process!.exitCode.timeout(
  Duration(seconds: 5),
  onTimeout: () {
    _process!.kill(ProcessSignal.sigkill);  // 强制停止
  },
);
```

### URL 解析技巧

#### Hysteria2/VLESS
```dart
final uri = Uri.parse(nodeUrl);
final uuid = uri.userInfo;      // @ 前面的部分
final server = uri.host;        // 域名/IP
final port = uri.port;          // 端口
final params = uri.queryParameters;  // ?后面的参数
```

#### VMess
```dart
final base64Part = nodeUrl.substring('vmess://'.length);
final decoded = utf8.decode(base64.decode(base64Part));
final config = json.decode(decoded) as Map<String, dynamic>;
```

## 🧪 测试验证

### 已测试场景

✅ Hysteria2 节点解析和配置生成  
✅ VMess 节点解析和配置生成（含emoji和中文）  
✅ VLESS 节点解析和配置生成  
✅ 配置文件正确性  
✅ 进程启动和停止  

### 待测试场景

⏳ 实际网络连接  
⏳ 多次切换节点  
⏳ 异常情况处理  
⏳ 系统代理设置  

## 🚧 已知限制

1. **Windows Only**
   - 当前仅支持 Windows 平台
   - 需要为其他平台适配

2. **基础功能**
   - 暂不支持 TUN 模式
   - 暂不支持高级路由规则
   - 暂不支持节点延迟测试

3. **依赖外部程序**
   - 需要用户手动放置 `sing-box.exe`
   - 需要确保 sing-box 版本兼容

## 🔜 后续优化方向

### 短期
- [ ] 添加节点延迟测试功能
- [ ] 支持系统代理自动设置
- [ ] 添加连接状态实时监控
- [ ] 优化错误提示信息

### 中期
- [ ] 支持 TUN 模式（需要管理员权限）
- [ ] 支持自定义路由规则
- [ ] 添加流量统计功能
- [ ] 支持更多协议（Trojan, Shadowsocks等）

### 长期
- [ ] 支持 Android/iOS/macOS/Linux
- [ ] 内置 sing-box 核心（使用FFI）
- [ ] 支持配置订阅更新
- [ ] 支持节点分组和智能选择

## 📞 问题排查

### 启动失败

**症状**: 点击节点后提示 "❌ 启动失败"

**排查步骤**:
1. 检查 `sing-box.exe` 是否存在
2. 查看 Flutter 控制台输出
3. 检查配置文件: `config/sing-box-config.json`
4. 手动运行: `sing-box.exe run -c config/sing-box-config.json`

### 配置生成失败

**症状**: 提示 "❌ 配置失败"

**排查步骤**:
1. 检查节点URL格式是否正确
2. 查看控制台错误信息
3. 确认协议是否支持（Hysteria2/VMess/VLESS）

### 连接无效

**症状**: sing-box 启动成功，但无法访问外网

**排查步骤**:
1. 检查节点是否有效（在其他客户端测试）
2. 配置系统代理: `127.0.0.1:15808`
3. 检查防火墙设置
4. 查看 sing-box 日志输出

## 📚 代码参考

### Karing 项目参考

本实现参考了 [Karing](https://github.com/KaringX/karing) 项目的以下部分：

1. **配置结构**: `README_examples/sing-box/`
2. **节点管理**: `lib/app/modules/server_manager.dart`
3. **配置生成**: `lib/screens/my_profiles_screen.dart`
4. **VPN服务**: `package:vpn_service`

### 关键差异

| 功能 | Karing | 本项目 |
|-----|--------|--------|
| 核心集成 | FFI + Go库 | 外部exe进程 |
| 配置生成 | Native调用 | Dart实现 |
| 进程管理 | VPN Service插件 | Process.start() |
| 平台支持 | 全平台 | 仅Windows |
| 复杂度 | 高 | 低 |

## 🎓 学习笔记

### Sing-box 配置关键点

1. **Inbounds（入站）**
   - `mixed`: 同时支持 HTTP 和 SOCKS5
   - `tun`: 虚拟网卡模式（需要管理员权限）

2. **Outbounds（出站）**
   - 第一个通常是代理节点
   - `direct`: 直连
   - `block`: 拦截
   - `dns`: DNS查询

3. **Route（路由）**
   - `final`: 默认出站
   - `rules`: 路由规则数组
   - `auto_detect_interface`: 自动检测网络接口

4. **DNS**
   - 国内域名用国内DNS
   - 国外域名用国外DNS
   - 避免DNS污染

### URI 解析技巧

```dart
// Hysteria2/VLESS 使用标准 URI 解析
final uri = Uri.parse(url);
uri.userInfo   // @ 前面
uri.host       // 主机名
uri.port       // 端口
uri.queryParameters  // 查询参数

// VMess 需要先 Base64 解码
final json = utf8.decode(base64.decode(base64Part));
final config = jsonDecode(json);
```

## 🎉 总结

通过参考 Karing 项目，我们实现了一个**简化版的 sing-box 集成方案**：

- **优点**:
  - ✅ 实现简单，易于理解和维护
  - ✅ 不需要编译 Go 代码
  - ✅ 不需要配置 FFI
  - ✅ 快速集成，功能完整

- **缺点**:
  - ⚠️ 依赖外部exe文件
  - ⚠️ 仅支持 Windows（当前）
  - ⚠️ 进程管理相对简单

对于您的需求（VPN客户端Demo），这个方案是**最佳选择**，在保证功能的同时大大降低了实现复杂度。

## 📖 下一步

建议按以下顺序进行测试和优化：

1. ✅ 测试节点配置生成（已完成）
2. 🔄 测试实际网络连接
3. 🔄 完善错误处理
4. 🔄 添加连接状态监控
5. 🔄 集成到首页连接按钮

---

**创建时间**: 2025-10-14  
**版本**: 1.0  
**作者**: AI Assistant

