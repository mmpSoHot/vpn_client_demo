# Sing-box 版本兼容性修复记录

## 🎯 当前配置兼容版本
✅ **sing-box 1.12.0+** 完全兼容

## 📋 修复的兼容性问题

### 1. DNS 服务器格式更新 (1.12.0)
**问题**: 旧的 DNS 地址格式已弃用

**解决方案**:
```json
// ❌ 旧格式
{
  "tag": "google",
  "address": "8.8.8.8"
}

// ✅ 新格式
{
  "tag": "google",
  "server": "8.8.8.8",
  "type": "udp"
}
```

### 2. 特殊 Outbound 迁移 (1.11.0)
**问题**: `"type": "dns"` 的 outbound 已弃用

**解决方案**:
- ❌ 移除: `{"type": "dns", "tag": "dns-out"}`
- ✅ 使用 route actions 替代:
```json
"route": {
  "rules": [
    {"action": "sniff"},
    {"protocol": "dns", "action": "hijack-dns"}
  ]
}
```

### 3. Geosite/Geoip 数据库移除 (1.12.0)
**问题**: 内置 geosite/geoip 数据库已移除

**解决方案**:
- ❌ 移除: `{"geosite": "cn", "geoip": ["cn", "private"]}`
- ✅ 使用简单规则: `{"ip_is_private": true, "outbound": "direct"}`

### 4. 默认域名解析器配置 (1.12.0)
**问题**: 缺少 `default_domain_resolver` 配置

**解决方案**:
```json
"route": {
  "default_domain_resolver": {
    "server": "google",
    "strategy": "prefer_ipv4"
  },
  "rules": [...]
}
```

### 5. DNS 服务器 detour 配置移除 (1.12.0)
**问题**: DNS 服务器不应配置 `detour` 到空的 direct outbound

**解决方案**:
```json
// ❌ 错误配置
{
  "tag": "local",
  "server": "223.5.5.5",
  "type": "udp",
  "detour": "direct"  // 会导致错误
}

// ✅ 正确配置
{
  "tag": "local",
  "server": "223.5.5.5",
  "type": "udp"  // 移除 detour
}
```

## 🔧 当前配置特点

### DNS 配置
- **Google DNS**: 8.8.8.8 (UDP) - 全局默认
- **阿里 DNS**: 223.5.5.5 (UDP) - 用于直连流量

### 路由规则
1. **流量嗅探**: 自动识别协议
2. **DNS 劫持**: 处理 DNS 请求
3. **私有 IP**: 直连（局域网流量）
4. **其他流量**: 通过代理节点

### 监听端口
- **Mixed 代理**: `127.0.0.1:15808`
- 支持 HTTP、SOCKS5、HTTPS

## 📝 配置示例

完整的兼容配置结构：

```json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "server": "8.8.8.8",
        "type": "udp"
      },
      {
        "tag": "local",
        "server": "223.5.5.5",
        "type": "udp"
      }
    ],
    "final": "google",
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 15808,
      "sniff": true,
      "sniff_override_destination": false
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2|vmess|vless",
      "tag": "节点名称",
      // 节点配置...
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "default_domain_resolver": {
      "server": "google",
      "strategy": "prefer_ipv4"
    },
    "rules": [
      {
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      }
    ],
    "final": "节点tag",
    "auto_detect_interface": true
  }
}
```

## ⚠️ 已弃用的功能

以下功能不再使用，避免在新配置中添加：

1. ❌ `"address"` 字段（DNS 服务器）
2. ❌ `{"type": "dns"}` outbound
3. ❌ `geosite`、`geoip` 规则
4. ❌ `{"protocol": "dns", "outbound": "dns-out"}` 路由规则

## 🚀 启动命令

```bash
# Windows
.\sing-box.exe run -c config\sing-box-config.json

# 检查配置
.\sing-box.exe check -c config\sing-box-config.json
```

## 📚 参考资源

- [Sing-box 迁移指南](https://sing-box.sagernet.org/migration/)
- [DNS 服务器格式迁移](https://sing-box.sagernet.org/migration/#migrate-to-new-dns-server-formats)
- [特殊 Outbound 迁移](https://sing-box.sagernet.org/migration/#migrate-legacy-special-outbounds-to-rule-actions)

