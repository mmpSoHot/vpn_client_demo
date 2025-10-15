# 节点持久化问题根本原因分析

## 问题现象

用户关闭应用后重新打开，点击"连接"按钮提示"请先选择节点"，即使之前已经选择过节点。

## 根本原因

通过详细的日志分析，发现了两个问题：

### 问题 1：节点对象未保存（主要原因）

**位置**：`lib/pages/home_page.dart` 的节点选择回调

**现象**：
```
🔍 [HomeContent] 开始加载保存的节点对象...
⚠️ [HomeContent] 节点配置为空: 🇺🇸 美国|01|0.8x|【新】
...
   节点名称: 🇺🇸 美国|01|0.8x|【新】
   rawConfig 是否为空: true  ← 关键！
```

**原因**：
在 `home_page.dart` 中选择节点时，代码是这样的：

```dart
// ❌ 修复前
if (selectedNodeModel != null) {
  setState(() {
    _selectedNodeModel = selectedNodeModel;
  });
  print('✅ 已选择节点: ${selectedNodeModel.displayName}');
  // 缺少：没有保存到持久化存储！
}
```

虽然更新了内存中的 `_selectedNodeModel`，但**没有调用 `NodeStorageService.saveSelectedNode()` 保存到持久化存储**。

而在 `_HomePage` 的 `_handleNodeChanged` 中，只保存了节点名称：

```dart
await NodeStorageService.saveSelectedNodeName(nodeName);  // 只保存名称
// 缺少：没有保存完整的节点对象！
```

### 问题 2：应用启动时未加载节点对象

**位置**：`HomeContent.initState()`

**现象**：
- 只有父组件 `_HomePage` 加载了节点名称
- 子组件 `HomeContent` 没有加载节点对象

**原因**：
`HomeContent` 的 `initState()` 中没有调用 `_loadSavedNode()` 来恢复节点对象。

## 修复方案

### 修复 1：选择节点时保存（已修复）✅

```dart
// ✅ 修复后
if (selectedNodeModel != null) {
  setState(() {
    _selectedNodeModel = selectedNodeModel;
  });
  
  // 保存节点对象到持久化存储
  await NodeStorageService.saveSelectedNode(selectedNodeModel);
  
  print('✅ 已选择节点: ${selectedNodeModel.displayName}');
  print('💾 节点已保存，rawConfig 长度: ${selectedNodeModel.rawConfig.length}');
}
```

### 修复 2：应用启动时加载（已修复）✅

```dart
@override
void initState() {
  super.initState();
  // ... 其他初始化 ...
  _loadSavedNode();  // ✅ 新增：加载节点对象
}

Future<void> _loadSavedNode() async {
  try {
    print('🔍 [HomeContent] 开始加载保存的节点对象...');
    final savedNode = await NodeStorageService.getSelectedNode();
    
    if (savedNode != null && savedNode.rawConfig.isNotEmpty) {
      setState(() {
        _selectedNodeModel = savedNode;
      });
      print('✅ [HomeContent] 恢复上次选择的节点对象: ${savedNode.displayName}');
    }
  } catch (e) {
    print('❌ [HomeContent] 加载保存的节点失败: $e');
  }
}
```

## 数据流程图

### 修复前（错误）

```
用户选择节点
    ↓
更新内存: _selectedNodeModel = nodeModel
    ↓
❌ 没有保存到存储
    ↓
[用户关闭应用]
    ↓
[重新打开应用]
    ↓
❌ 存储中没有完整的节点对象
    ↓
_selectedNodeModel = null
    ↓
点击连接 → ❌ "请先选择节点"
```

### 修复后（正确）

```
用户选择节点
    ↓
更新内存: _selectedNodeModel = nodeModel
    ↓
✅ 保存到存储: NodeStorageService.saveSelectedNode()
    ↓
[用户关闭应用]
    ↓
[重新打开应用]
    ↓
✅ 从存储加载: _loadSavedNode()
    ↓
_selectedNodeModel = savedNode (包含 rawConfig)
    ↓
点击连接 → ✅ 成功连接
```

## 关键字段说明

### NodeModel 结构

```dart
class NodeModel {
  final String name;           // 节点名称，例如: "🇺🇸 美国|01|0.8x|【新】"
  final String protocol;       // 协议类型，例如: "Hysteria2"
  final String location;       // 位置信息
  final String rawConfig;      // ⭐ 关键！完整的节点配置字符串
  final String? rate;          // 倍率信息
  final String type;           // 类型：premium/standard
}
```

**rawConfig** 是最关键的字段，它包含了：
- 服务器地址
- 端口号
- 密码/UUID
- 加密方式
- 传输协议
- TLS 配置
- 等等...

没有 `rawConfig`，就无法生成 sing-box 配置，也就无法连接！

## 测试验证

### 测试步骤

1. **热重启应用** (按 `r`)
2. **选择一个节点**
3. **查看日志**，应该看到：
   ```
   ✅ 已选择节点: 🇺🇸 美国|01|0.8x|【新】
   💾 节点已保存，rawConfig 长度: 123  ← 应该是一个大于0的数字
   ```
4. **热重启应用** (再按 `r`)
5. **查看日志**，应该看到：
   ```
   🔍 [HomeContent] 开始加载保存的节点对象...
   ✅ [HomeContent] 恢复上次选择的节点对象: 🇺🇸 美国|01
      协议: Hysteria2
      配置长度: 123  ← 应该和上面保存的长度一致
   ```
6. **点击连接**
7. **查看日志**，应该看到：
   ```
   🔍 [连接] 检查节点: _selectedNodeModel = 🇺🇸 美国|01
   ✅ [连接] 使用内存中的节点: 🇺🇸 美国|01
   ```
8. **连接应该成功** ✅

### 预期结果

- ✅ 选择节点后能够连接
- ✅ 重启应用后节点信息保留
- ✅ 重启后直接点击连接能够成功
- ✅ 不再提示"请先选择节点"

## 历史遗留问题

这个问题可能一直存在，但之前没有被发现，原因是：

1. **节点切换时会自动连接**：在 `node_selection_page.dart` 中，切换节点时会调用 `_switchNodeInBackground()` 后台切换，这个过程中节点对象已经在内存中。

2. **热重启会保留内存状态**：在开发过程中使用热重启 (`r`)，内存中的 `_selectedNodeModel` 不会丢失。

3. **完全重启才会暴露问题**：只有完全退出应用并重新启动（冷启动），才会清空内存，这时才会发现节点对象没有正确恢复。

## 总结

**核心问题**：选择节点时没有保存完整的节点对象（特别是 `rawConfig` 字段）到持久化存储。

**解决方案**：
1. ✅ 在选择节点时调用 `NodeStorageService.saveSelectedNode()` 保存完整对象
2. ✅ 在应用启动时调用 `_loadSavedNode()` 恢复节点对象
3. ✅ 添加详细日志帮助调试

**修复文件**：`lib/pages/home_page.dart`

---

**修复时间**：2025-10-15
**根本原因**：节点对象保存缺失
**修复状态**：✅ 已完成

