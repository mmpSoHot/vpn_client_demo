# VMess 和 VLESS 配置对比

## VLESS 配置

### 参考配置（v2rayN 生成）
```json
{
  "server": "hyld.jsyd.bs0584.plnode.xyz",
  "server_port": 36983,
  "uuid": "ee784b9c-353d-4083-b53e-6abfdb2a9053",
  "flow": "xtls-rprx-vision",
  "packet_encoding": "xudp",
  "type": "vless",
  "tag": "proxy",
  "tls": {
    "enabled": true,
    "server_name": "bs-vless-68sb823q.plnode.xyz",
    "insecure": false,
    "record_fragment": false
  }
}
```

### 我们的实现
```dart
// 从 URL 解析参数
mode=multi → packet_encoding: "xudp"
flow=xtls-rprx-vision → flow: "xtls-rprx-vision"
security=tls → tls.enabled: true
sni=xxx → tls.server_name: xxx
```

### VLESS URL 示例
```
vless://uuid@server:port?mode=multi&security=tls&encryption=none&type=tcp&flow=xtls-rprx-vision&sni=xxx#name
```

### 关键字段说明

1. **flow**: VLESS 流控模式
   - `xtls-rprx-vision` - Vision 流控（推荐）
   - `xtls-rprx-direct` - Direct 流控
   - 空 - 无流控

2. **packet_encoding**: 数据包编码
   - `xudp` - 多路复用 UDP（对应 mode=multi）
   - `packetaddr` - 包地址模式

3. **record_fragment**: TLS 记录分片
   - `false` - 不分片（推荐）
   - `true` - 分片（某些场景需要）

## VMess 配置

### 参考配置（v2rayN 生成）
```json
{
  "server": "TNL-01.PLNODE.XYZ",
  "server_port": 46453,
  "uuid": "ee784b9c-353d-4083-b53e-6abfdb2a9053",
  "security": "auto",
  "alter_id": 0,
  "type": "vmess",
  "tag": "proxy"
}
```

### 我们的实现
```dart
// 从 base64 JSON 解析
add → server
port → server_port
id → uuid
aid → alter_id
security → security (默认 "auto")
```

### VMess URL 示例
```
vmess://base64({
  "v": "2",
  "ps": "节点名称",
  "add": "server.com",
  "port": "443",
  "id": "uuid",
  "aid": "0",
  "net": "tcp",
  "type": "none",
  "host": "",
  "path": "",
  "tls": ""
})
```

### 关键字段说明

1. **security**: 加密方式
   - `auto` - 自动选择（推荐）
   - `aes-128-gcm` - AES-128-GCM
   - `chacha20-poly1305` - ChaCha20-Poly1305
   - `none` - 无加密

2. **alter_id**: 额外ID
   - `0` - 不使用（推荐，新版本）
   - `1-255` - 额外ID数量（旧版本）

3. **net**: 传输协议
   - `tcp` - TCP（默认）
   - `ws` - WebSocket
   - `grpc` - gRPC
   - `h2` - HTTP/2

## 可能的连接失败原因

### 1. TLS 配置问题

**VLESS with flow**：
- ✅ 应该使用 TLS
- ❌ 不应该有 `record_fragment`（使用 flow 时）

**VLESS without flow**：
- ✅ 应该使用 TLS
- ✅ 应该添加 `record_fragment: false`

### 2. packet_encoding 缺失

VLESS 的 `mode=multi` 参数需要转换为：
```json
{
  "packet_encoding": "xudp"
}
```

### 3. 传输层配置

对于非 TCP 传输（ws, grpc），需要添加 `transport` 配置。

## 修复内容

### VLESS 改进

1. ✅ 添加 `packet_encoding` 支持（从 mode 参数解析）
2. ✅ 优化 TLS 配置（根据是否有 flow 决定是否添加 record_fragment）
3. ✅ 保持 flow 参数

### VMess 保持不变

VMess 配置看起来已经正确，应该能正常工作。

## 测试建议

1. **查看生成的配置文件**：
   ```bash
   cat config/sing-box-config.json
   ```

2. **检查 outbounds 部分**：
   确认所有必需字段都存在

3. **查看 sing-box 日志**：
   ```
   sing-box.exe run -c config/sing-box-config.json
   ```
   查看具体的连接错误

4. **对比字段**：
   将生成的配置与参考配置对比，看是否有差异

## 调试步骤

如果还是无法连接：

1. **验证节点 URL**：
   打印原始的节点 URL，确认解析是否正确

2. **检查参数解析**：
   打印所有解析出的参数值

3. **测试最小配置**：
   只使用必需字段，逐步添加可选字段

4. **查看错误日志**：
   sing-box 会输出具体的连接失败原因

