# Geo 规则文件设置指南

## 什么是 Geo 规则文件？

Geo 规则文件用于实现"绕过大陆"代理模式，包含以下内容：
- **geosite-cn.srs**: 中国大陆网站域名列表
- **geosite-private.srs**: 私有网络域名列表（局域网等）
- **geoip-cn.srs**: 中国大陆 IP 地址段列表

## 为什么需要这些文件？

在"绕过大陆"模式下，应用会根据这些规则文件判断：
- 访问国内网站 → 直连（不走代理）
- 访问国外网站 → 走代理服务器
- 访问私有网络 → 直连

这样可以加快国内网站的访问速度，同时节省代理流量。

## ✅ 规则文件已内置

**好消息！** 规则文件已经内置在项目中，无需下载！

规则文件位置：`项目根目录/srss/`

包含的文件：
- ✅ geosite-cn.srs (约 425 KB)
- ✅ geosite-private.srs (约 1 KB)
- ✅ geoip-cn.srs (约 77 KB)

以及其他扩展规则文件：
- geosite-gfw.srs (GFW 列表)
- geosite-category-ads-all.srs (广告过滤)
- geoip-google.srs, geoip-facebook.srs 等

### 使用代码下载

```dart
import 'package:vpn_client_demo/utils/geo_rules_downloader.dart';

// 下载所有规则文件
final results = await GeoRulesDownloader.downloadAllRules(
  onProgress: (rule, progress) {
    print('正在下载: $rule - ${(progress * 100).toStringAsFixed(0)}%');
  },
);

// 检查规则文件是否存在
final exists = await GeoRulesDownloader.checkRulesExist();
print('geosite-cn: ${exists['geosite-cn'] ? '已存在' : '未找到'}');
```

## 手动下载

如果自动下载失败，可以手动下载：

### 下载地址

- **geosite-cn.srs**: https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite-cn.srs
- **geosite-private.srs**: https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite-private.srs
- **geoip-cn.srs**: https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip-cn.srs

### 存放位置

将下载的文件放置到以下目录：

**Windows:**
```
C:\Users\你的用户名\.vpn_client_demo\rules\
```

**macOS/Linux:**
```
~/.vpn_client_demo/rules/
```

**Android:**
```
/data/data/com.example.vpn_client_demo/files/rules/
```

**iOS:**
```
/var/mobile/Containers/Data/Application/vpn_client_demo/Documents/rules/
```

## 验证安装

### 方法 1：查看文件

打开规则文件目录，确认以下文件存在：
- ✅ geosite-cn.srs (约 1-2 MB)
- ✅ geosite-private.srs (约 10-50 KB)
- ✅ geoip-cn.srs (约 100-200 KB)

### 方法 2：查看日志

VPN 连接时，如果规则文件缺失，日志会显示警告：
```
⚠️ 规则文件不存在: C:\Users\...\geosite-cn.srs
```

如果规则文件加载成功，日志会显示：
```
✅ 已加载规则文件: geosite-cn
```

## 更新规则文件

规则文件会定期更新（通常每月一次），建议定期更新：

### 自动更新（未来功能）
```dart
// 检查更新
final needsUpdate = await GeoRulesDownloader.checkForUpdates();

// 更新规则文件
if (needsUpdate) {
  await GeoRulesDownloader.downloadAllRules();
}
```

### 手动更新
1. 删除旧的规则文件
2. 重新下载最新版本

## 故障排除

### 问题 1：下载失败

**原因**：
- 网络连接问题
- GitHub 访问受限
- 防火墙阻止

**解决方案**：
1. 检查网络连接
2. 使用代理访问 GitHub（需要先连接 VPN）
3. 手动下载并放置文件

### 问题 2：规则文件无效

**症状**：
- VPN 连接失败
- 日志显示"规则文件加载失败"

**解决方案**：
1. 重新下载规则文件
2. 确认文件完整性（检查文件大小）
3. 删除损坏的文件，重新下载

### 问题 3：绕过大陆模式不生效

**检查清单**：
- ✅ 规则文件是否存在
- ✅ 规则文件路径是否正确
- ✅ sing-box 配置是否包含 rule_set
- ✅ 路由规则是否正确配置

## 不使用规则文件

如果不需要"绕过大陆"模式，可以：
1. 只使用"全局代理"模式（不需要规则文件）
2. 配置会自动适配，不会因为缺少规则文件而报错

## 规则文件来源

- **sing-geosite**: https://github.com/SagerNet/sing-geosite
- **sing-geoip**: https://github.com/SagerNet/sing-geoip

这些是 sing-box 官方维护的规则文件，数据来源于：
- GFWList
- China IP List
- Private Network Ranges

## 隐私说明

规则文件仅包含：
- 域名列表
- IP 地址段

**不包含**：
- 用户数据
- 浏览记录
- 个人信息

所有规则文件都是开源的，可以在 GitHub 上查看完整内容。

