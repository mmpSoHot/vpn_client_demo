# 节点延迟测试功能

## ✅ 已实现功能

实现了**真实的节点延迟测试**，通过实际代理请求测试节点速度，支持 Hysteria2 等 UDP 协议。

## 🎯 测试原理

### 为什么不用 TCP/Ping 测试？

- ❌ **TCP 连接**：Hysteria2 是 UDP 协议，TCP 连接无法真实反映延迟
- ❌ **ICMP Ping**：只测试网络层，不测试代理层，且需要管理员权限
- ✅ **HTTP 代理请求**：通过实际的代理请求测试，最真实的延迟数据

### 测试流程

```
1. 启动临时 sing-box (端口 18808)
2. 通过代理发送 HTTP 请求到 https://www.gstatic.com/generate_204
3. 测量请求完成时间
4. 停止临时 sing-box
5. 返回延迟结果
```

## 📦 新增工具

### `NodeLatencyTester` (`lib/utils/node_latency_tester.dart`)

**主要方法**：

```dart
// 测试单个节点
int latency = await NodeLatencyTester.testNodeLatency(nodeModel);

// 测试多个节点
Map<String, int> results = await NodeLatencyTester.testMultipleNodes(nodes);

// 格式化延迟显示
String display = NodeLatencyTester.formatLatency(150); // "150ms"

// 获取延迟对应的颜色
Color color = NodeLatencyTester.getLatencyColor(150); // 橙色
```

## 🎨 延迟颜色标准

| 延迟范围 | 颜色 | 等级 | 说明 |
|---------|------|------|------|
| < 100ms | 🟢 绿色 | 优秀 | 非常快速 |
| 100-300ms | 🟠 橙色 | 良好 | 正常使用 |
| > 300ms | 🔴 红色 | 较慢 | 可能卡顿 |
| 超时 | ⚫ 灰色 | 失败 | 节点不可用 |
| 未测试 | ⚫ 灰色 | -- | 未测试 |

## 🔧 功能特性

### 1. 节点选择页面功能

**顶部测试按钮** 📡
- 点击左上角的测速图标
- 自动测试所有节点
- 显示加载动画
- 结果自动保存

**单个节点测试** 🔄
- 每个节点右侧有刷新按钮
- 点击测试该节点延迟
- 实时更新显示
- 可随时重新测试

**延迟显示** 📊
- 自动显示延迟数值
- 颜色标记（绿/橙/红/灰）
- 支持 "--" 未测试状态
- 支持 "超时" 失败状态

### 2. 延迟结果持久化

```dart
// 自动保存到 SharedPreferences
{
  "node_latency_results": {
    "香港 01": 25,
    "新加坡 01": 45,
    "日本 01": 65,
    "美国 01": 120
  }
}
```

**优势**：
- ✅ 重启应用后仍然显示延迟
- ✅ 无需重新测试
- ✅ 可随时刷新

### 3. 测试配置

**测试URL**: `https://www.gstatic.com/generate_204`
- Google 的轻量级测试端点
- 返回 204 No Content
- 全球CDN，速度快
- 稳定可靠

**临时端口**: `18808`
- 避免与主端口 15808 冲突
- 测试完立即释放

**超时时间**: `5秒`
- 超过5秒标记为超时
- 返回 -1

## 📊 UI 界面

### 节点列表显示

```
┌────────────────────────────────────┐
│  📡 节点选择                    ✕  │
├────────────────────────────────────┤
│                                    │
│  📍 香港 01          [25ms]  🔄 ✓  │
│     香港                            │
│                                    │
│  📍 新加坡 01        [45ms]  🔄    │
│     新加坡                          │
│                                    │
│  📍 日本 01          [--]    🔄    │
│     日本                            │
│                                    │
│  📍 美国 01          [超时]  🔄    │
│     美国                            │
│                                    │
└────────────────────────────────────┘

图例：
📡 - 测试所有节点按钮
[25ms] - 延迟显示（带颜色）
🔄 - 单个节点测试按钮
✓ - 当前选中标记
```

### 测试中状态

```
┌────────────────────────────────────┐
│  ⏳ 节点选择                    ✕  │
│     (测试中...)                     │
├────────────────────────────────────┤
│                                    │
│  📍 香港 01          [25ms]  ✅    │
│                                    │
│  📍 新加坡 01        [测试中] ⏳   │
│                                    │
│  📍 日本 01          [--]    🔄    │
│                                    │
└────────────────────────────────────┘
```

## 🔄 工作流程

### 测试所有节点

```dart
// 用户点击左上角测速按钮
await _testAllNodesLatency();

// 流程：
1. setState(_isTesting = true)  // 显示加载动画
2. 遍历所有节点
3. 依次测试每个节点
4. 实时更新UI显示
5. 保存测试结果
6. setState(_isTesting = false)
```

### 测试单个节点

```dart
// 用户点击节点的刷新按钮
await _testSingleNodeLatency(nodeName, nodeModel);

// 流程：
1. 测试该节点
2. 更新该节点的延迟显示
3. 保存结果
```

### 加载历史结果

```dart
// 页面加载时
@override
void initState() {
  super.initState();
  _loadNodes();
  _loadLatencyResults();  // 加载历史测试结果
}
```

## 💡 技术实现细节

### 1. 使用临时 sing-box 实例

```dart
// 生成配置（使用临时端口 18808）
await SingboxManager.generateConfigFromNode(
  node: node,
  mixedPort: 18808,  // 不影响正在运行的主实例
);

// 启动临时实例
final process = await Process.start(
  SingboxManager.getSingboxPath(),
  ['run', '-c', SingboxManager.getConfigPath()],
);
```

### 2. HTTP 代理请求

```dart
// 设置代理
final httpClient = HttpClient()
  ..findProxy = (uri) => 'PROXY 127.0.0.1:18808';

// 发送请求
final stopwatch = Stopwatch()..start();
final response = await httpClient.getUrl(Uri.parse(testUrl));
stopwatch.stop();

// 获取延迟
int latency = stopwatch.elapsedMilliseconds;
```

### 3. 进程清理

```dart
// 测试完成后立即清理
process.kill(ProcessSignal.sigterm);
await Future.delayed(const Duration(milliseconds: 200));
```

## ⚠️ 注意事项

### 1. 顺序测试避免冲突

```dart
// ❌ 不要并行测试
for (final node in nodes) {
  await Future.wait([test1, test2, test3]);  // 会导致端口冲突
}

// ✅ 顺序测试
for (final node in nodes) {
  await testNodeLatency(node);
  await Future.delayed(Duration(milliseconds: 300));  // 等待清理
}
```

### 2. 超时处理

- 每个节点最多等待 5 秒
- 超时返回 -1
- UI 显示为 "超时"

### 3. 防火墙问题

如果所有节点都超时：
- 检查防火墙是否阻止 sing-box
- 检查网络连接
- 尝试手动测试

## 🧪 测试步骤

### 1. 测试所有节点

1. 打开节点选择页面
2. 点击左上角的 📡 图标
3. 等待测试完成（可能需要1-2分钟）
4. 查看所有节点的延迟

### 2. 测试单个节点

1. 找到想测试的节点
2. 点击右侧的 🔄 按钮
3. 等待几秒
4. 延迟值更新

### 3. 查看测试结果

延迟会以颜色标记：
- 🟢 绿色：< 100ms（优秀）
- 🟠 橙色：100-300ms（良好）
- 🔴 红色：> 300ms（较慢）
- ⚫ 灰色：超时或未测试

## 🎁 额外功能

### 延迟缓存

- ✅ 测试结果自动保存
- ✅ 重启应用后仍然显示
- ✅ 可手动刷新

### 自动排序（可扩展）

```dart
// 未来可按延迟排序节点
_nodes.sort((a, b) {
  final latencyA = _latencyResults[a['name']] ?? 9999;
  final latencyB = _latencyResults[b['name']] ?? 9999;
  return latencyA.compareTo(latencyB);
});
```

### 最优节点推荐（可扩展）

```dart
// 自动选择延迟最低的节点
NodeModel? getBestNode() {
  var minLatency = 9999;
  NodeModel? bestNode;
  
  for (var entry in _latencyResults.entries) {
    if (entry.value > 0 && entry.value < minLatency) {
      minLatency = entry.value;
      bestNode = findNodeByName(entry.key);
    }
  }
  
  return bestNode;
}
```

## 🐛 常见问题

### Q: 为什么测试需要这么久？

A: 每个节点需要：
- 启动 sing-box (800ms)
- 发送请求 (实际延迟)
- 停止 sing-box (200ms)
- 总计约 1-2 秒/节点

**优化建议**：
- 只测试常用的几个节点
- 使用后台任务测试
- 缓存结果避免频繁测试

### Q: 所有节点都显示超时？

可能原因：
1. 防火墙阻止 sing-box
2. 节点配置错误
3. 网络问题
4. sing-box.exe 路径错误

**解决方法**：
```powershell
# 检查 sing-box 是否可用
.\sing-box.exe version

# 手动测试节点
.\sing-box.exe run -c config\sing-box-config.json
```

### Q: 延迟不准确？

**说明**：
- 延迟包含了 sing-box 启动时间
- 首次请求可能较慢（DNS 解析等）
- 多次测试取平均值更准确

**改进**：
点击刷新按钮重新测试该节点

## 📝 代码示例

### 在代码中使用

```dart
import 'package:demo2/utils/node_latency_tester.dart';

// 测试节点
final latency = await NodeLatencyTester.testNodeLatency(nodeModel);

if (latency > 0) {
  print('节点延迟: $latency ms');
} else {
  print('节点连接失败');
}

// 显示延迟
final display = NodeLatencyTester.formatLatency(latency);  // "150ms"
final color = NodeLatencyTester.getLatencyColor(latency);  // 橙色
```

## 🚀 使用演示

### 场景 1：首次选择节点

```
1. 打开节点选择页面
2. 点击 📡 测试所有节点
3. 等待测试完成
4. 查看延迟，选择最快的节点
5. ✅ 获得最佳体验
```

### 场景 2：节点变慢了

```
1. 打开节点选择页面  
2. 点击当前节点的 🔄 按钮
3. 查看最新延迟
4. 如果变慢，切换到其他节点
5. ✅ 保持最佳速度
```

### 场景 3：重启应用

```
1. 应用启动
2. 自动加载历史延迟数据
3. ✅ 无需重新测试
4. 如需更新，点击 📡 重新测试
```

## 📊 测试数据示例

```json
// SharedPreferences 存储
{
  "node_latency_results": {
    "香港 01": 25,
    "香港 02": 18,
    "新加坡 01": 45,
    "新加坡 02": 52,
    "日本 01": 65,
    "美国 01": 120,
    "美国 02": 135,
    "英国 01": -1  // 超时
  }
}
```

## 🎯 UI 效果

### 节点列表项

```
┌───────────────────────────────────────────┐
│ 🌍 香港 01                   [Hysteria2]  │
│    香港                                    │
│                            [25ms] 🔄  ✓   │
│                            └─绿色─┘        │
└───────────────────────────────────────────┘
```

### 测试进度

```
测试节点 1/10...
🔍 测试节点延迟: 香港 01
✅ 香港 01 延迟: 25ms

测试节点 2/10...
🔍 测试节点延迟: 新加坡 01
✅ 新加坡 01 延迟: 45ms

...
```

## 🔧 配置说明

### 测试参数

```dart
class NodeLatencyTester {
  // 测试URL（Google的轻量级端点）
  static const String _testUrl = 'https://www.gstatic.com/generate_204';
  
  // 临时测试端口
  static const int _testPort = 18808;
  
  // 超时时间
  static const int _timeout = 5; // 秒
}
```

### 可自定义参数

```dart
// 修改测试URL
static const String _testUrl = 'https://www.cloudflare.com/cdn-cgi/trace';

// 修改临时端口
static const int _testPort = 19808;

// 修改超时时间
timeout: Duration(seconds: 10),  // 更长的超时
```

## 📈 性能优化

### 当前实现

- 顺序测试：避免端口冲突
- 每个节点间隔 300ms：确保进程完全清理
- 缓存结果：避免重复测试

### 未来优化

1. **后台测试**：
   ```dart
   // 使用 Isolate 后台测试
   await compute(testAllNodes, nodes);
   ```

2. **并行优化**：
   ```dart
   // 使用不同端口并行测试
   // Port 18808, 18809, 18810...
   ```

3. **智能测试**：
   ```dart
   // 只测试最近使用的节点
   // 或定期自动测试
   ```

## 🆕 新增文件

- `lib/utils/node_latency_tester.dart` - 延迟测试工具

## ✅ 修改文件

- `lib/pages/node_selection_page.dart` - 添加延迟显示和测试
- `lib/services/node_storage_service.dart` - 添加 getPreferences 方法

## 📚 相关文档

- `NODE_PERSISTENCE_GUIDE.md` - 节点持久化
- `VPN_CONNECTION_IMPLEMENTATION.md` - VPN 连接实现
- `TROUBLESHOOTING.md` - 问题排查

## ✅ 功能总结

通过 `NodeLatencyTester`，实现了：

✅ **真实的延迟测试**
- 通过实际代理请求测试
- 支持 Hysteria2 等 UDP 协议
- 准确反映实际使用速度

✅ **完整的UI集成**
- 节点列表显示延迟
- 颜色标记速度等级
- 一键测试所有节点
- 单个节点快速刷新

✅ **智能缓存**
- 延迟结果持久化
- 重启应用仍然显示
- 支持手动刷新

✅ **优秀的用户体验**
- 实时显示测试进度
- 加载动画反馈
- 自动保存结果

🎉 **现在节点列表会显示真实的延迟数据了！**

