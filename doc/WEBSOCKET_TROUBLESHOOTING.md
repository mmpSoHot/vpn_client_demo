# WebSocket 网速监控故障排除

## 问题描述

WebSocket 连接到 sing-box Clash API 时出现 "远程计算机拒绝网络连接" 错误。

## 可能原因

### 1. sing-box 版本不支持 Clash API
某些版本的 sing-box 可能不支持 `experimental.clash_api` 配置。

**检查方法：**
```bash
# 查看 sing-box 版本
sing-box.exe version

# 查看 sing-box 日志，看是否有 API 启动信息
```

**解决方案：**
- 使用支持 Clash API 的 sing-box 版本（1.8.0+ 推荐）
- 或者下载最新的 sing-box 版本

### 2. API 端口未正确监听
sing-box 启动后可能没有正确启动 Clash API。

**检查方法：**
```bash
# Windows
netstat -ano | findstr "9090"

# 应该看到类似以下输出：
# TCP    127.0.0.1:9090         0.0.0.0:0              LISTENING       12345
```

**解决方案：**
- 检查 sing-box 配置文件中的 `experimental.clash_api` 部分
- 确保端口没有被其他程序占用
- 查看 sing-box 启动日志，看是否有错误信息

### 3. WebSocket 连接时机问题
应用可能在 sing-box 完全启动 API 之前就尝试连接。

**当前实现：**
- VPN 连接成功后延迟 5 秒才启动 WebSocket 监控
- 最多尝试重连 3 次
- 超过 3 次后停止重连，避免刷屏

### 4. sing-box Clash API 不支持 WebSocket
某些 sing-box 版本的 Clash API 可能只支持 HTTP REST API，不支持 WebSocket。

**替代方案：**
- 改用 HTTP 轮询方式（详见下文）
- 使用 Clash 或 Clash.Meta 核心（它们完全支持 Clash API）

## 临时解决方案

如果 WebSocket 一直无法连接，可以暂时使用 HTTP 轮询方式：

### 方案 1：修改为 HTTP 轮询

修改 `lib/services/websocket_speed_service.dart`：

```dart
// 将 WebSocket 连接改为 HTTP 轮询
Timer? _pollingTimer;

void startMonitoring() {
  _pollingTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:9090/traffic'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 处理数据...
      }
    } catch (e) {
      // 错误处理...
    }
  });
}

void stopMonitoring() {
  _pollingTimer?.cancel();
}
```

### 方案 2：禁用网速监控

如果不需要实时网速显示，可以临时禁用：

1. 注释掉 `home_page.dart` 中的网速监控启动代码：
```dart
// Future.delayed(const Duration(seconds: 5), () {
//   if (mounted && widget.isProxyEnabled) {
//     print('🚀 启动网速监控服务...');
//     _speedService.startMonitoring();
//   }
// });
```

2. 在流量统计卡片中显示静态文本或占位符

## 推荐配置

### sing-box 配置示例

```json
{
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "",
      "secret": "",
      "default_mode": "rule"
    },
    "cache_file": {
      "enabled": true,
      "path": "cache.db"
    }
  }
}
```

### 测试 Clash API 是否可用

VPN 连接后，在浏览器中访问：

```
# 测试 API 是否响应
http://127.0.0.1:9090/

# 测试版本信息
http://127.0.0.1:9090/version
```

**重要**：`/traffic` 端点只支持 WebSocket 连接，不能直接用浏览器访问。
- WebSocket URL: `ws://127.0.0.1:9090/traffic`
- 每秒推送一次流量数据：`{"up": xxx, "down": xxx}`

## 当前优化

1. **延迟启动**：VPN 连接成功后延迟 5 秒启动 WebSocket 监控
2. **重连限制**：最多尝试 3 次重连，避免无限重连
3. **错误抑制**：只在 Debug 模式显示详细错误信息
4. **优雅降级**：连接失败时显示 "0 B/s"，不影响主要功能

## 未来改进

1. **智能检测**：启动时先检测 API 是否可用，再决定使用 WebSocket 还是 HTTP 轮询
2. **多种方式**：支持 WebSocket、HTTP 轮询、sing-box stats 等多种方式
3. **用户设置**：允许用户选择是否启用网速监控
4. **更好的反馈**：在 UI 上显示网速监控状态（连接中/已连接/不可用）

## 参考资料

- [sing-box 官方文档 - Experimental](https://sing-box.sagernet.org/configuration/experimental/)
- [Clash API 文档](https://clash.gitbook.io/doc/restful-api)
- [karing 项目 - WebSocket 实现](https://github.com/KaringX/karing)

