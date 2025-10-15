# 最新更新说明

## 2025年2月更新

### 1. 全局代理和绕过大陆模式 ✅

**功能描述**：
- 支持两种代理模式：绕过大陆（智能分流）和全局代理
- 可以在 VPN 运行时动态切换模式
- 模式选择会持久化保存

**技术实现**：
- 修改了 `node_config_converter.dart` 支持不同模式的配置生成
- 更新了 `singbox_manager.dart` 传递代理模式参数
- 在 `home_page.dart` 实现了运行时切换功能

**使用方法**：
1. 在首页"功能"区块选择"绕过大陆"或"全局代理"
2. VPN 运行时切换会自动重启 sing-box 应用新配置

### 2. WebSocket 实时网速监控 ✅

**功能描述**：
- 实时显示上传/下载速度
- 使用 sing-box Clash API 的 WebSocket 端点
- 自动重连机制（最多 3 次）

**技术实现**：
- 创建了 `websocket_speed_service.dart` 服务
- 使用 Clash API 的 `/traffic` WebSocket 端点
- 数据格式：`{"up": bytes/s, "down": bytes/s}`

**修复的问题**：
- ❌ 之前错误使用了 `/connections/` 端点
- ✅ 现在使用正确的 `/traffic` 端点
- ✅ 添加了重连限制，避免无限重连
- ✅ 只在 Debug 模式显示详细错误

### 3. Geo 规则文件内置 ✅

**功能描述**：
- 规则文件已内置在项目 `srss/` 目录
- 无需下载，开箱即用
- 支持绕过大陆模式所需的所有规则

**包含的规则文件**：
- `geosite-cn.srs` (425 KB) - 中国大陆网站
- `geosite-private.srs` (1 KB) - 私有网络
- `geoip-cn.srs` (77 KB) - 中国大陆 IP
- 以及其他扩展规则（GFW、广告过滤等）

**技术实现**：
- 修改了 `node_config_converter.dart` 使用项目中的规则文件
- 在 `pubspec.yaml` 中添加了 `srss/` 资源配置
- 规则文件会自动打包到应用中

### 4. 配置优化

**路径管理**：
- 规则文件：使用项目中的 `srss/` 目录
- 缓存数据库：使用用户目录 `.vpn_client_demo/cache.db`
- 配置文件：使用项目 `config/` 目录

**sing-box 配置**：
- 绕过大陆模式：完整的 DNS 和路由规则
- 全局代理模式：简化的规则，更快的启动速度
- Clash API：端口 9090，支持 WebSocket

## 配置示例

### 绕过大陆模式特点
```yaml
DNS:
  - 国内 DNS 直连
  - 国外 DNS 走代理
  - hosts predefined 支持

路由规则:
  - 私有 IP → 直连
  - 中国 IP → 直连
  - 中国网站 → 直连
  - Google 服务 → 代理
  - 其他 → 代理

规则集:
  - geosite-cn
  - geosite-private
  - geoip-cn
```

### 全局代理模式特点
```yaml
DNS:
  - 所有 DNS 走代理

路由规则:
  - 私有 IP → 直连
  - 其他所有 → 代理

规则集:
  - geosite-private (仅私有网络)
```

## 文件结构

```
vpn_client_demo/
├── srss/                          # 规则文件目录（已内置）
│   ├── geosite-cn.srs
│   ├── geosite-private.srs
│   ├── geoip-cn.srs
│   └── ...
├── config/                        # 配置文件目录
│   └── sing-box-config.json
├── lib/
│   ├── services/
│   │   ├── websocket_speed_service.dart   # WebSocket 网速监控
│   │   └── proxy_mode_service.dart        # 代理模式管理
│   └── utils/
│       ├── node_config_converter.dart     # 配置生成器
│       ├── singbox_manager.dart           # sing-box 管理
│       └── geo_rules_downloader.dart      # 规则文件下载（备用）
└── doc/
    ├── NETWORK_SPEED_IMPLEMENTATION.md    # 网速监控文档
    ├── GEO_RULES_SETUP.md                 # 规则文件说明
    └── WEBSOCKET_TROUBLESHOOTING.md       # 故障排除
```

## 使用须知

### 1. sing-box 版本要求
- 推荐版本：1.8.0 或更高
- 必须支持 Clash API
- 必须支持 WebSocket `/traffic` 端点

### 2. 网络要求
- Clash API 端口：9090
- 代理端口：15808 (HTTP/SOCKS5 混合)
- 确保端口未被占用

### 3. 规则文件
- ✅ 已内置在项目中
- ✅ 无需手动下载
- ✅ 自动打包到应用
- 路径：`srss/` 目录

### 4. 代理模式切换
- 可以在 VPN 运行时切换
- 会自动重启 sing-box
- 切换过程约需 1-2 秒

## 故障排除

### WebSocket 连接失败
**症状**：显示 "远程计算机拒绝网络连接"

**可能原因**：
1. sing-box 未运行
2. Clash API 未启用
3. 端口被占用

**解决方案**：
1. 检查 sing-box 是否正在运行
2. 检查配置中是否有 `experimental.clash_api`
3. 检查端口 9090 是否可用

### 规则文件加载失败
**症状**：VPN 连接失败，日志显示规则文件错误

**可能原因**：
1. 规则文件路径错误
2. 规则文件损坏
3. 权限问题

**解决方案**：
1. 检查 `srss/` 目录是否存在
2. 重新下载项目
3. 检查文件权限

### 代理模式不生效
**症状**：切换模式后没有效果

**检查清单**：
- ✅ sing-box 是否重启成功
- ✅ 配置文件是否更新
- ✅ 路由规则是否正确
- ✅ 规则文件是否加载

## 性能优化

1. **启动速度**：
   - 绕过大陆模式：约 2-3 秒
   - 全局代理模式：约 1-2 秒（规则更少）

2. **内存占用**：
   - 规则文件加载：约 1-2 MB
   - WebSocket 连接：约 100-200 KB

3. **网络延迟**：
   - WebSocket 更新频率：1 秒
   - 重连间隔：5 秒

## 下一步计划

1. **UI 改进**：
   - [ ] 添加网速图表
   - [ ] 显示连接状态指示器
   - [ ] 优化模式切换动画

2. **功能扩展**：
   - [ ] 支持自定义规则
   - [ ] 支持规则文件更新
   - [ ] 添加流量统计历史

3. **性能优化**：
   - [ ] 减少启动时间
   - [ ] 优化内存占用
   - [ ] 改进重连机制

## 相关文档

- [网速监控实现](./doc/NETWORK_SPEED_IMPLEMENTATION.md)
- [规则文件设置](./doc/GEO_RULES_SETUP.md)
- [故障排除指南](./doc/WEBSOCKET_TROUBLESHOOTING.md)
- [VPN 连接实现](./doc/VPN_CONNECTION_IMPLEMENTATION.md)

## 更新日志

### 2025-02-18
- ✅ 实现全局代理和绕过大陆模式
- ✅ 修复 WebSocket 端点为 `/traffic`
- ✅ 内置规则文件到项目
- ✅ 优化配置生成逻辑
- ✅ 添加运行时模式切换
- ✅ 改进错误处理和重连机制

