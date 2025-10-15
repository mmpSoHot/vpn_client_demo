# Sing-box 集成使用说明

## 📋 功能概述

本项目已集成 sing-box 核心，支持以下功能：

- ✅ 支持 Hysteria2、VMess、VLESS 协议节点
- ✅ 自动解析订阅链接中的节点
- ✅ 点击节点自动生成配置并连接
- ✅ 支持节点切换（自动停止旧连接）
- ✅ 配置文件自动管理

## 🚀 快速开始

### 1. 准备工作

确保 `sing-box.exe` 已放置在项目根目录：
```
vpn_client_demo/
├── lib/
├── sing-box.exe  ← 这里
└── ...
```

### 2. 使用流程

#### 方式一：通过节点选择页面

1. **登录账号**
   - 确保已登录并有有效订阅

2. **选择节点**
   - 在首页点击"选择节点"
   - 从底部弹出的节点列表中选择节点
   - **点击节点后会自动**：
     - 生成 sing-box 配置文件
     - 启动 sing-box 进程
     - 建立代理连接

3. **查看连接状态**
   - 成功：显示绿色提示 "✅ 已连接到：xxx"
   - 失败：显示红色提示 "❌ 启动失败"

#### 方式二：通过测试页面（开发调试）

1. **打开测试页面**
   - 点击首页右上角的 🐛 图标
   - 进入 "Sing-box 测试" 页面

2. **生成配置**
   - 点击 "生成配置文件" 按钮
   - 配置文件保存在 `config/sing-box-config.json`

3. **启动/停止**
   - 点击 "启动 sing-box" 开始代理
   - 点击 "停止 sing-box" 停止代理
   - 点击 "重启 sing-box" 重新加载配置

## 📂 文件结构

```
lib/
├── utils/
│   ├── singbox_manager.dart           # Sing-box 管理器
│   └── node_config_converter.dart     # 节点配置转换器
├── models/
│   └── node_model.dart                # 节点数据模型
└── pages/
    ├── node_selection_page.dart       # 节点选择页面
    └── singbox_test_page.dart         # 测试页面

config/                                 # 自动创建
└── sing-box-config.json               # 配置文件
```

## 🔧 核心组件说明

### 1. SingboxManager

**位置**: `lib/utils/singbox_manager.dart`

**主要方法**:
```dart
// 生成配置并保存
await SingboxManager.generateConfigFromNode(
  node: nodeModel,
  mixedPort: 15808,
  enableTun: false,
);

// 启动 sing-box
bool started = await SingboxManager.start();

// 停止 sing-box
bool stopped = await SingboxManager.stop();

// 检查运行状态
bool running = SingboxManager.isRunning();

// 重启
bool restarted = await SingboxManager.restart();
```

### 2. NodeConfigConverter

**位置**: `lib/utils/node_config_converter.dart`

**功能**: 将节点URL转换为 Sing-box 配置

**支持的协议**:

#### Hysteria2
```
hysteria2://uuid@server:port?sni=xxx&security=tls&insecure=1#name
```

#### VMess
```
vmess://base64(json)
```
JSON格式：
```json
{
  "add": "server",
  "port": "443",
  "id": "uuid",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "example.com",
  "path": "/path",
  "tls": "tls"
}
```

#### VLESS
```
vless://uuid@server:port?encryption=none&security=tls&type=ws&path=/&host=xxx#name
```

### 3. 配置文件格式

生成的配置文件包含以下部分：

```json
{
  "log": {...},           // 日志配置
  "dns": {...},           // DNS 配置
  "inbounds": [...],      // 入站（本地监听）
  "outbounds": [...],     // 出站（代理节点）
  "route": {...}          // 路由规则
}
```

## 🎯 代理配置

### 本地代理端口

- **Mixed 代理**: `127.0.0.1:15808`
  - 支持 HTTP 和 SOCKS5
  - 可在系统代理设置中配置

### 路由规则

- 🇨🇳 **国内直连**: 
  - 国内网站和IP直接访问
  - 使用国内DNS（223.5.5.5）

- 🌍 **国外代理**:
  - 其他流量走代理
  - 使用Google DNS（8.8.8.8）

- 🚫 **广告拦截**:
  - 自动拦截广告域名

## 🔍 调试信息

### 查看日志

Sing-box 运行时会在控制台输出日志：

```
[sing-box] level=info msg="started" 
[sing-box] level=info msg="inbound/mixed started"
```

### 配置文件位置

```
项目根目录/config/sing-box-config.json
```

### 常见问题

1. **启动失败**
   - 检查 `sing-box.exe` 是否存在
   - 查看控制台错误日志
   - 确认配置文件格式正确

2. **连接失败**
   - 检查节点是否有效
   - 确认网络连接正常
   - 查看 sing-box 日志

3. **端口被占用**
   - 修改 `mixedPort` 参数
   - 检查其他程序是否占用 15808 端口

## 📝 开发说明

### 添加新协议支持

1. 在 `NodeConfigConverter` 中添加转换方法
2. 在 `NodeModel` 中添加协议识别
3. 更新配置生成逻辑

### 自定义路由规则

修改 `NodeConfigConverter.generateFullConfig()` 中的 `route` 部分

### 修改代理端口

```dart
await SingboxManager.generateConfigFromNode(
  node: nodeModel,
  mixedPort: 10809, // 自定义端口
);
```

## 🔐 安全提示

- ⚠️ 配置文件包含敏感信息（UUID、密码等）
- ⚠️ 不要将配置文件提交到代码仓库
- ⚠️ 生产环境建议加密存储节点信息

## 📚 参考资料

- [Sing-box 官方文档](https://sing-box.sagernet.org/)
- [配置示例](https://github.com/SagerNet/sing-box/tree/main/docs/configuration)
- [Karing 项目](https://github.com/KaringX/karing)

