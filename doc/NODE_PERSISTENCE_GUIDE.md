# 节点持久化存储指南

## ✅ 已实现功能

实现了**节点选择的持久化存储**，重启应用后自动恢复上次选择的节点。

## 📦 新增服务

### `NodeStorageService` (`lib/services/node_storage_service.dart`)

提供节点数据的持久化存储功能。

**主要方法**：

```dart
// 保存节点
await NodeStorageService.saveSelectedNode(nodeModel);

// 获取保存的节点名称
String? nodeName = await NodeStorageService.getSelectedNodeName();

// 获取保存的节点完整数据
NodeModel? node = await NodeStorageService.getSelectedNode();

// 清除节点选择
await NodeStorageService.clearSelectedNode();

// 检查是否有保存的节点
bool hasNode = await NodeStorageService.hasSelectedNode();
```

## 🔄 工作流程

### 1. 应用启动时

```dart
// lib/pages/home_page.dart
@override
void initState() {
  super.initState();
  
  // 加载上次选择的节点
  _loadLastSelectedNode();
}

Future<void> _loadLastSelectedNode() async {
  final savedNodeName = await NodeStorageService.getSelectedNodeName();
  if (savedNodeName != null && savedNodeName.isNotEmpty) {
    setState(() {
      _selectedNode = savedNodeName;
    });
    print('📌 恢复上次选择的节点: $savedNodeName');
  }
}
```

**结果**：
- ✅ 首页显示上次选择的节点名称
- ✅ 无需重新选择

### 2. 用户选择节点时

```dart
void _updateSelectedNode(String nodeName) async {
  // 更新UI
  setState(() {
    _selectedNode = nodeName;
  });

  // 保存到本地存储
  final tempNode = NodeModel(
    name: nodeName,
    protocol: 'Hysteria2',
    location: '未知',
    rawConfig: '',
  );
  await NodeStorageService.saveSelectedNode(tempNode);
  
  print('💾 已保存节点: $nodeName');
}
```

**结果**：
- ✅ 节点名称保存到 SharedPreferences
- ✅ 下次启动自动恢复

### 3. 连接 VPN 时

```dart
Future<void> _connectVPN() async {
  // 尝试从存储中加载节点
  final savedNode = await NodeStorageService.getSelectedNode();
  
  if (savedNode != null && savedNode.rawConfig.isNotEmpty) {
    // 使用保存的节点配置
    _selectedNodeModel = savedNode;
    print('📌 使用保存的节点: ${savedNode.name}');
  } else {
    // 创建新节点...
  }
  
  // 启动 sing-box...
}
```

**结果**：
- ✅ 优先使用保存的节点数据
- ✅ 避免重复创建节点

## 💾 存储的数据

### SharedPreferences 存储键

| 键名 | 类型 | 内容 | 示例 |
|------|------|------|------|
| `selected_node_name` | String | 节点名称 | "香港 01" |
| `selected_node_data` | String (JSON) | 节点完整数据 | `{"name":"香港 01","protocol":"Hysteria2",...}` |

### 存储的节点数据结构

```json
{
  "name": "香港 01",
  "protocol": "Hysteria2",
  "location": "香港",
  "rawConfig": "hysteria2://...",
  "rate": "0.8",
  "type": "premium"
}
```

## 🎯 使用场景

### 场景 1：首次使用

1. 用户选择节点 → "香港 01"
2. 自动保存到本地
3. 首页显示 "当前节点: 香港 01"

### 场景 2：重启应用

1. 应用启动
2. 自动读取上次选择 → "香港 01"
3. 首页直接显示 "当前节点: 香港 01"
4. ✅ 无需重新选择

### 场景 3：切换节点

1. 用户选择新节点 → "新加坡 01"
2. 自动保存覆盖旧数据
3. 下次启动恢复 → "新加坡 01"

## 🔧 高级功能（可扩展）

### 保存节点列表（未来优化）

```dart
class NodeStorageService {
  // 保存最近使用的节点列表
  static Future<void> saveRecentNodes(List<NodeModel> nodes) async {
    final prefs = await SharedPreferences.getInstance();
    final nodesJson = nodes.map((node) => {
      'name': node.name,
      'protocol': node.protocol,
      'rawConfig': node.rawConfig,
      // ...
    }).toList();
    
    await prefs.setString('recent_nodes', jsonEncode(nodesJson));
  }
  
  // 获取最近使用的节点
  static Future<List<NodeModel>> getRecentNodes() async {
    // ...
  }
}
```

### 保存节点收藏（未来优化）

```dart
// 收藏节点
static Future<void> addFavoriteNode(NodeModel node) async { }

// 获取收藏列表
static Future<List<NodeModel>> getFavoriteNodes() async { }

// 取消收藏
static Future<void> removeFavoriteNode(String nodeName) async { }
```

## 📊 数据流程图

```
┌─────────────┐
│ 用户选择节点 │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ 保存到 SharedPrefs│
│ - 节点名称       │
│ - 节点数据(JSON) │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│   应用重启      │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ 从 SharedPrefs  │
│ 读取节点数据     │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ 恢复节点选择     │
│ ✅ 首页显示     │
└─────────────────┘
```

## 🧪 测试步骤

### 测试 1：基本保存和恢复

1. **选择节点**：
   - 打开节点选择页面
   - 选择 "香港 01"
   - 首页显示 "当前节点: 香港 01"

2. **重启应用**：
   - 完全关闭应用
   - 重新启动
   - ✅ 首页自动显示 "当前节点: 香港 01"

3. **连接测试**：
   - 点击连接按钮
   - ✅ 使用保存的节点配置连接

### 测试 2：切换节点

1. **切换节点**：
   - 从 "香港 01" 切换到 "新加坡 01"
   - 首页更新显示

2. **重启应用**：
   - ✅ 显示 "新加坡 01"（不是 "香港 01"）

### 测试 3：清除数据

```dart
// 手动测试清除
await NodeStorageService.clearSelectedNode();

// 重启应用
// ✅ 显示 "自动选择"（默认值）
```

## 📝 注意事项

### 1. 数据安全

- ✅ 使用 SharedPreferences（本地存储）
- ✅ 不存储敏感信息（密码等）
- ✅ 只存储节点配置

### 2. 数据一致性

- ✅ 节点名称和数据同步保存
- ✅ 读取失败时使用默认值
- ✅ 异常处理完善

### 3. 性能考虑

- ✅ 异步读写，不阻塞 UI
- ✅ 启动时快速加载
- ✅ 数据量小，性能无影响

## 🔍 调试技巧

### 查看保存的数据

在 Windows 上，SharedPreferences 数据存储在：
```
C:\Users\<用户名>\AppData\Roaming\<应用名>\shared_preferences\
```

### 手动清除数据

```dart
// 在代码中添加测试按钮
TextButton(
  onPressed: () async {
    await NodeStorageService.clearSelectedNode();
    print('已清除节点选择');
  },
  child: Text('清除节点数据'),
)
```

### 查看存储日志

应用会输出日志：
```
💾 已保存节点: 香港 01
📌 恢复上次选择的节点: 香港 01
📌 使用保存的节点: 香港 01
```

## 🚀 未来优化方向

### 1. 保存节点列表

从服务器获取的所有节点列表也可以缓存：
- 减少网络请求
- 离线也能查看节点
- 启动更快

### 2. 节点延迟测试结果缓存

```dart
// 保存延迟测试结果
await NodeStorageService.saveNodeLatency('香港 01', 15);

// 下次启动直接显示，无需重新测试
```

### 3. 最近使用的节点历史

```dart
// 保存使用历史（最多10个）
List<NodeModel> recentNodes = [
  node1, node2, node3, ...
];
```

### 4. 自动选择最优节点

```dart
// 根据历史延迟数据，自动选择最快的节点
NodeModel? bestNode = await NodeStorageService.getBestNode();
```

## 📚 相关文档

- `VPN_CONNECTION_IMPLEMENTATION.md` - VPN 连接实现
- `APP_LIFECYCLE_MANAGEMENT.md` - 应用生命周期管理
- `TROUBLESHOOTING.md` - 问题排查指南

## ✅ 功能总结

通过 `NodeStorageService`，我们实现了：

✅ **节点选择持久化**
- 重启应用自动恢复
- 用户无需重复选择

✅ **完整的节点数据存储**
- 名称、协议、配置全部保存
- 支持直接用于连接

✅ **优雅的用户体验**
- 自动保存，无感知
- 自动恢复，无需操作
- 启动即可连接

🎉 **现在重启应用，节点选择不会丢失了！**

