# 节点持久化修复

## 问题描述

用户反馈：关闭应用后再打开，点击"连接"提示"请先选择节点"，但之前已经选择过节点了。

## 根本原因

`HomeContent` 组件的 `initState()` 中只在父组件 `HomePage` 中加载了节点名称（`_selectedNode`），但没有加载节点对象（`_selectedNodeModel`）。

连接 VPN 时需要完整的 `NodeModel` 对象（包含服务器地址、端口、密码等配置信息），而不仅仅是节点名称。

## 代码分析

### 修复前

```dart
// HomeContent 的 initState
@override
void initState() {
  super.initState();
  _loadSubscribeInfo();
  _startStatusChecker();
  _loadProxyModeLocal();  // 只加载了代理模式
  // ❌ 没有加载节点对象
}
```

### 修复后

```dart
// HomeContent 的 initState
@override
void initState() {
  super.initState();
  _loadSubscribeInfo();
  _startStatusChecker();
  _loadProxyModeLocal();
  _loadSavedNode();  // ✅ 新增：加载节点对象
}

/// 加载保存的节点对象
Future<void> _loadSavedNode() async {
  try {
    final savedNode = await NodeStorageService.getSelectedNode();
    if (savedNode != null && savedNode.rawConfig.isNotEmpty) {
      setState(() {
        _selectedNodeModel = savedNode;
      });
      print('📌 恢复上次选择的节点对象: ${savedNode.displayName}');
    }
  } catch (e) {
    print('⚠️ 加载保存的节点失败: $e');
  }
}
```

## 节点持久化流程

### 1. 节点选择时

```dart
// 用户选择节点
onTap: () async {
  final selectedNodeModel = await NodeSelectionPage.show(...);
  
  if (selectedNodeModel != null) {
    // 更新内存中的节点对象
    setState(() {
      _selectedNodeModel = selectedNodeModel;
    });
    
    // 保存到持久化存储
    await NodeStorageService.saveSelectedNode(selectedNodeModel);
  }
}
```

### 2. 应用启动时

```dart
// HomeContent.initState()
@override
void initState() {
  super.initState();
  _loadSavedNode();  // 从存储恢复节点对象
}

Future<void> _loadSavedNode() async {
  final savedNode = await NodeStorageService.getSelectedNode();
  if (savedNode != null) {
    _selectedNodeModel = savedNode;  // 恢复到内存
  }
}
```

### 3. 连接 VPN 时

```dart
Future<void> _connectVPN() async {
  // 优先使用内存中的节点对象
  if (_selectedNodeModel == null) {
    // 如果内存中没有，尝试从存储加载（双保险）
    final savedNode = await NodeStorageService.getSelectedNode();
    if (savedNode != null) {
      _selectedNodeModel = savedNode;
    } else {
      _showError('请先选择节点');
      return;
    }
  }
  
  // 使用节点对象生成配置并连接
  await SingboxManager.generateConfigFromNode(node: _selectedNodeModel!);
  // ...
}
```

## 测试验证

### 测试步骤

1. **选择节点**
   - 打开应用
   - 登录账号
   - 点击"节点选择"
   - 选择一个节点（例如：🇺🇸 美国|01）
   - 确认页面显示选中的节点名称

2. **第一次连接**
   - 点击"连接"按钮
   - 应该能够成功连接
   - 确认状态显示"已连接"

3. **断开并关闭应用**
   - 点击"断开"按钮
   - 完全关闭应用（不是最小化）

4. **重新打开应用**
   - 重新打开应用
   - 查看控制台输出，应该看到：
     ```
     📌 恢复上次选择的节点对象: 🇺🇸 美国|01|0.8x|【新】
     ```

5. **再次连接**
   - 点击"连接"按钮
   - ✅ 应该能够成功连接（不再提示"请先选择节点"）

### 预期日志

#### 修复前（错误）
```
[应用重启]
[用户点击连接]
❌ 请先选择节点
```

#### 修复后（正确）
```
[应用重启]
📌 恢复上次选择的节点对象: 🇺🇸 美国|01|0.8x|【新】
[用户点击连接]
🚀 启动 VPN...
   节点: 🇺🇸 美国|01|0.8x|【新】
   协议: Hysteria2
✅ VPN 连接成功
```

## 相关代码文件

- `lib/pages/home_page.dart` - 主页面，包含连接逻辑
- `lib/services/node_storage_service.dart` - 节点持久化服务
- `lib/models/node_model.dart` - 节点数据模型

## 双重保险机制

为了确保用户体验，我们实现了双重检查：

1. **应用启动时主动加载**：`initState()` 中调用 `_loadSavedNode()`
2. **连接时被动检查**：`_connectVPN()` 中检查 `_selectedNodeModel`，如果为空则再次尝试加载

这样即使第一次加载失败（例如，存储读取延迟），也能在连接时再次尝试。

## 潜在问题和解决方案

### 问题 1：存储读取失败

**现象**：即使修复后，仍然提示"请先选择节点"

**原因**：
- `shared_preferences` 读取失败
- 节点数据损坏
- 权限问题

**解决**：
- 添加了 try-catch 错误处理
- 打印详细日志便于调试

### 问题 2：节点对象序列化问题

**现象**：保存成功，但读取失败

**检查**：
- `NodeModel.toJson()` 和 `NodeModel.fromJson()` 是否正确
- 是否所有字段都正确序列化

## 总结

**修复内容**：
- ✅ 在 `HomeContent.initState()` 中添加 `_loadSavedNode()` 调用
- ✅ 实现 `_loadSavedNode()` 方法从存储恢复节点对象
- ✅ 添加错误处理和日志输出

**效果**：
- ✅ 用户选择节点后，关闭并重新打开应用，节点选择状态正确恢复
- ✅ 可以直接点击"连接"，无需重新选择节点
- ✅ 提升用户体验

---

**修复时间**：2025-10-15
**修复文件**：`lib/pages/home_page.dart`

