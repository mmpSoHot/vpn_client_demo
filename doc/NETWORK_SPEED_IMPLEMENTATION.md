# 实时网速监控实现文档

## 概述

本文档描述了在 VPN 客户端中实现实时网速监控功能的方案选择和实现细节。

## 方案选择

经过分析 karing 的实现方式，我们选择了 **WebSocket 实时连接** 作为实现方案。

### 为什么选择 WebSocket 方案？

1. **实时性更好**：WebSocket 提供真正的实时数据传输，无需轮询
2. **资源效率高**：避免频繁的 HTTP 请求，减少网络开销
3. **参考成熟方案**：karing 使用相同方案，已经过验证
4. **连接稳定性**：自动重连机制，网络中断后能自动恢复
5. **数据完整性**：WebSocket 连接能保证数据传输的完整性

## 实现架构

```
┌─────────────────┐    WebSocket    ┌─────────────────┐
│   Flutter App   │ ◄─────────────► │   sing-box      │
│                 │                 │   Clash API     │
│ WebSocketSpeed  │  实时数据流      │   Port: 9090    │
│ Service         │                 │                 │
└─────────────────┘                 └─────────────────┘
```

## 核心组件

### 1. WebSocketSpeedService

位置：`lib/services/websocket_speed_service.dart`

主要功能：
- WebSocket 连接管理
- 实时接收网速数据
- 自动重连机制
- 数据解析和格式化

### 2. sing-box 配置

在 `config/sing-box-config.json` 中添加了 Clash API 配置：

```json
{
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "",
      "secret": ""
    }
  }
}
```

### 3. 首页集成

在 `lib/pages/home_page.dart` 中集成：
- VPN 连接成功后自动启动 WebSocket 监控
- VPN 断开后自动停止 WebSocket 监控
- 实时更新流量统计卡片显示

## WebSocket 端点

### Clash API 流量端点
- **URL**: `ws://127.0.0.1:9090/traffic`
- **协议**: WebSocket (sing-box Clash API)
- **数据格式**: JSON
- **响应示例**:
```json
{
  "up": 1024,    // 上传速度 (bytes/s)
  "down": 2048   // 下载速度 (bytes/s)
}
```

**说明**：
- sing-box 的 Clash API 通过 `/traffic` WebSocket 端点推送实时流量数据
- 数据每秒更新一次
- `up` 表示当前上传速度（字节/秒）
- `down` 表示当前下载速度（字节/秒）

## 使用方式

### 启动监控
```dart
final speedService = WebSocketSpeedService();
speedService.startMonitoring();
```

### 停止监控
```dart
speedService.stopMonitoring();
```

### 监听速度变化
```dart
ValueListenableBuilder<String>(
  valueListenable: speedService.uploadSpeedNotifier,
  builder: (context, speed, child) {
    return Text(speed);
  },
)
```

## 错误处理

服务包含完善的错误处理机制：

1. **连接失败**：自动重试连接，5秒间隔
2. **数据解析错误**：记录错误日志，继续接收后续数据
3. **连接中断**：自动检测并重新建立连接
4. **应用生命周期**：应用暂停时自动断开，恢复时自动重连

## 性能优化

1. **单例模式**：避免重复创建服务实例
2. **连接复用**：WebSocket 连接复用，减少握手开销
3. **内存管理**：及时清理 WebSocket 连接和监听器
4. **UI 更新**：使用 ValueNotifier 减少不必要的重建

## 调试功能

开发模式下提供详细的调试信息：
- WebSocket 连接状态
- 接收到的数据内容
- 连接错误和重连日志

## 依赖包

需要添加以下依赖到 `pubspec.yaml`：

```yaml
dependencies:
  web_socket_channel: ^3.0.1
```

## 注意事项

1. **端口冲突**：确保 9090 端口未被其他服务占用
2. **防火墙设置**：确保本地防火墙允许 9090 端口访问
3. **sing-box 版本**：需要支持 experimental.clash_api 配置的版本
4. **WebSocket 支持**：确保 sing-box 版本支持 WebSocket 连接
5. **资源清理**：应用退出时要正确停止 WebSocket 连接

## 与 karing 的对比

| 特性 | 我们的实现 | karing 实现 |
|------|------------|-------------|
| 连接方式 | WebSocket | WebSocket |
| 数据格式 | JSON | JSON |
| 重连机制 | 5秒自动重连 | 自动重连 |
| 错误处理 | 完善的错误处理 | 完善的错误处理 |
| 性能 | 实时传输 | 实时传输 |

## 未来扩展

1. **历史数据记录**：可以扩展为记录历史网速数据
2. **流量统计**：可以添加总流量统计功能
3. **多节点监控**：可以监控不同节点的网速表现
4. **图表显示**：可以添加网速变化图表
5. **连接详情**：可以显示详细的连接信息