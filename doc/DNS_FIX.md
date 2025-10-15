# DNS 配置修复说明

## 问题描述

之前的配置使用 DNS over HTTPS (DoH) 方式：
```json
{
  "server": "cloudflare-dns.com",
  "type": "https",
  "path": "/dns-query"
}
```

这导致了以下错误：
```
ERROR dns: lookup failed for www.google.com: (exchange4: authentication failed, status code: 400)
```

## 问题原因

1. **DoH 需要 HTTPS 连接**：DoH 服务器需要建立 HTTPS 连接，但如果代理节点未正确连接，会导致认证失败
2. **域名解析依赖问题**：DoH 服务器本身的域名（如 `cloudflare-dns.com`）也需要先解析，形成循环依赖
3. **复杂性高**：DoH 配置需要额外的 `domain_resolver` 和 `hosts` 配置

## 解决方案

改用简单可靠的 **UDP DNS** 方式：

### 修改前（DoH）
```json
{
  "servers": [
    {
      "server": "cloudflare-dns.com",
      "domain_resolver": "hosts_dns",
      "path": "/dns-query",
      "type": "https",
      "tag": "remote_dns",
      "detour": "proxy"
    }
  ]
}
```

### 修改后（UDP）
```json
{
  "servers": [
    {
      "server": "8.8.8.8",
      "type": "udp",
      "tag": "remote_dns",
      "detour": "proxy"
    }
  ]
}
```

## DNS 服务器选择

### 国内 DNS（直连）
- **223.5.5.5** - 阿里 DNS
- **223.6.6.6** - 阿里 DNS 备用
- **114.114.114.114** - 114 DNS
- **119.29.29.29** - DNSPod

### 国外 DNS（走代理）
- **8.8.8.8** - Google DNS（主）
- **8.8.4.4** - Google DNS（备用）
- **1.1.1.1** - Cloudflare DNS
- **1.0.0.1** - Cloudflare DNS 备用

## 新的 DNS 配置结构

### 绕过大陆模式
```json
{
  "servers": [
    {
      "server": "223.5.5.5",
      "type": "udp",
      "tag": "final_resolver"
    },
    {
      "server": "8.8.8.8",
      "type": "udp",
      "tag": "remote_dns",
      "detour": "proxy"
    },
    {
      "server": "223.5.5.5",
      "type": "udp",
      "tag": "direct_dns"
    },
    {
      "server": "223.5.5.5",
      "type": "udp",
      "tag": "outbound_resolver"
    }
  ],
  "rules": [
    {
      "server": "outbound_resolver",
      "domain": ["节点服务器域名"]
    },
    {
      "server": "remote_dns",
      "clash_mode": "Global"
    },
    {
      "server": "direct_dns",
      "clash_mode": "Direct"
    },
    {
      "server": "direct_dns",
      "rule_set": ["geosite-private", "geosite-cn"]
    }
  ],
  "final": "remote_dns"
}
```

### 全局代理模式
```json
{
  "servers": [
    {
      "server": "223.5.5.5",
      "type": "udp",
      "tag": "final_resolver"
    },
    {
      "server": "8.8.8.8",
      "type": "udp",
      "tag": "remote_dns",
      "detour": "proxy"
    },
    {
      "server": "223.5.5.5",
      "type": "udp",
      "tag": "direct_dns"
    }
  ],
  "rules": [
    {
      "server": "outbound_resolver",
      "domain": ["节点服务器域名"]
    },
    {
      "server": "direct_dns",
      "rule_set": ["geosite-private"]
    }
  ],
  "final": "remote_dns"
}
```

## DNS 解析流程

### 绕过大陆模式
1. **节点服务器域名** → `outbound_resolver` (223.5.5.5) → 直连解析
2. **私有网络/中国网站** → `direct_dns` (223.5.5.5) → 直连解析
3. **国外网站** → `remote_dns` (8.8.8.8) → 通过代理解析

### 全局代理模式
1. **节点服务器域名** → `outbound_resolver` (223.5.5.5) → 直连解析
2. **私有网络** → `direct_dns` (223.5.5.5) → 直连解析
3. **其他所有** → `remote_dns` (8.8.8.8) → 通过代理解析

## 优点

1. **简单可靠**：UDP DNS 是最基础的 DNS 协议，兼容性好
2. **无依赖**：不需要额外的域名解析
3. **快速**：UDP 延迟低，无需 HTTPS 握手
4. **稳定**：不会出现认证失败等问题

## 缺点

1. **不加密**：UDP DNS 是明文传输（但对于大多数场景足够）
2. **可能被污染**：国内 DNS 可能对某些域名返回错误结果（通过代理的 DNS 可以避免）

## 未来改进

如果需要使用加密 DNS，可以考虑：

1. **DNS over TLS (DoT)**：
```json
{
  "server": "8.8.8.8",
  "type": "tls",
  "tag": "remote_dns",
  "detour": "proxy"
}
```

2. **DNS over QUIC (DoQ)**：
```json
{
  "server": "dns.adguard.com",
  "type": "quic",
  "tag": "remote_dns",
  "detour": "proxy"
}
```

但需要确保：
- sing-box 版本支持
- 代理节点连接正常
- 配置正确的域名解析器

## 测试方法

1. **检查 DNS 解析**：
```bash
nslookup www.google.com 8.8.8.8
```

2. **检查配置有效性**：
```bash
sing-box.exe check -c config\sing-box-config.json
```

3. **查看日志**：
启动 sing-box 后观察是否还有 DNS 错误

## 相关文件

- `lib/utils/node_config_converter.dart` - DNS 配置生成逻辑
- `config/sing-box-config.json` - 实际使用的配置文件

