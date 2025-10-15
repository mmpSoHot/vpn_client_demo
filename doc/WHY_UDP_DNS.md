# 为什么使用 UDP DNS 而不是 DoH

## 问题背景

v2rayN 的参考配置使用了 DNS over HTTPS (DoH)，但在我们的应用中会导致以下错误：

```
ERROR dns: lookup failed: authentication failed, status code: 400
```

## 原因分析

### 1. DoH 的依赖问题

DoH 需要：
```
代理节点连接成功 → DoH 服务器可访问 → DNS 解析成功
```

但这形成了**循环依赖**：
- 要连接代理节点，需要先解析节点的域名
- 要解析域名，需要 DNS 服务器
- 要访问 DoH DNS 服务器（如 `cloudflare-dns.com`），又需要先解析它的域名
- 即使使用 `hosts_dns` 解析 DoH 服务器的 IP，DoH 本身也需要通过代理访问

### 2. v2rayN 为什么能用 DoH？

v2rayN 可以使用 DoH 是因为：
1. **长期运行**：v2rayN 通常长期保持连接，DoH 初始化后会缓存
2. **预热机制**：v2rayN 会预先解析和缓存 DNS 服务器
3. **更复杂的启动流程**：有多个阶段的 DNS 初始化

### 3. 我们的场景不同

我们的应用：
- **频繁启停**：用户可能频繁连接/断开 VPN
- **简单流程**：追求快速连接，不适合复杂的预热
- **移动优先**：需要在各种网络环境下都能快速工作

## 解决方案：UDP DNS

### UDP DNS 的优点

1. **零依赖**：
   ```
   UDP DNS → 直接查询 IP:53 → 立即返回结果
   ```
   不需要 HTTPS 连接，不需要解析 DNS 服务器的域名

2. **快速启动**：
   - DoH: 需要 TLS 握手 + HTTP 请求 ≈ 200-500ms
   - UDP: 单个 UDP 包 ≈ 10-50ms

3. **容错性好**：
   - 网络问题时 UDP DNS 仍然可能工作
   - DoH 需要完整的 HTTPS 连接

4. **资源占用少**：
   - 无需维护 HTTPS 连接
   - 内存占用更少

### DNS 服务器选择

**国内 DNS（直连）**：
- `223.5.5.5` - 阿里云 DNS
  - 速度快
  - 稳定性好
  - 支持 IPv4/IPv6

**国外 DNS（走代理）**：
- `8.8.8.8` - Google Public DNS
  - 全球覆盖
  - 防污染
  - 速度快

## 配置对比

### v2rayN 配置（DoH）
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
    },
    {
      "predefined": {
        "cloudflare-dns.com": ["104.16.249.249", "..."]
      },
      "type": "hosts",
      "tag": "hosts_dns"
    }
  ]
}
```

### 我们的配置（UDP）
```json
{
  "servers": [
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
  ]
}
```

## 性能对比

| 指标 | UDP DNS | DoH |
|------|---------|-----|
| 启动时间 | 快 (10-50ms) | 慢 (200-500ms) |
| 内存占用 | 低 | 中等 |
| 稳定性 | 高 | 中等 |
| 隐私性 | 中等 | 高 |
| 防污染 | 中等 | 高 |
| 复杂度 | 低 | 高 |

## 安全考虑

### UDP DNS 的风险
1. **明文传输**：DNS 查询可能被监听
2. **DNS 污染**：某些域名可能返回错误 IP

### 缓解措施
1. **使用可信 DNS**：
   - 国内：阿里云 DNS (223.5.5.5)
   - 国外：Google DNS (8.8.8.8) 通过代理

2. **分流策略**：
   - 国内网站用国内 DNS（直连）
   - 国外网站用国外 DNS（走代理）

3. **规则过滤**：
   - 使用 geosite-cn 规则自动分流
   - 已知被污染的域名强制走代理 DNS

## 未来优化

如果需要更高的安全性，可以考虑：

### 1. DNS over TLS (DoT)
```json
{
  "server": "8.8.8.8",
  "type": "tls",
  "tag": "remote_dns",
  "detour": "proxy"
}
```

优点：
- 加密传输
- 性能比 DoH 好（无 HTTP 层）
- 依赖少于 DoH

### 2. 混合方案
```json
{
  "servers": [
    {
      "server": "8.8.8.8",
      "type": "udp",
      "tag": "remote_dns_udp"
    },
    {
      "server": "8.8.8.8",
      "type": "tls",
      "tag": "remote_dns_tls",
      "detour": "proxy"
    }
  ],
  "strategy": "prefer_udp_fallback_tls"
}
```

## 结论

对于我们的 VPN 客户端，**UDP DNS 是最佳选择**：
- ✅ 简单可靠
- ✅ 快速启动
- ✅ 低资源占用
- ✅ 适合频繁连接/断开的场景
- ✅ 跨平台兼容性好

如果用户有特殊的隐私需求，将来可以添加 DoT 或 DoH 作为可选功能。

