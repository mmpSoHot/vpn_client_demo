# 节点选择修复说明

## 问题描述

之前的配置文件中节点服务器总是显示 `"server": "example.com"`，导致连接失败和 DNS 错误。

## 问题原因

**节点数据流程断裂**：

1. 节点选择页面只返回了节点**名称**（字符串）
2. 首页接收节点名称后，使用**占位符数据**创建节点
3. 占位符节点的服务器地址是 `example.com`（无效）
4. 导致配置生成时使用了无效的服务器地址

## 修复方案

### 修改前的流程

```
节点选择页面
  ↓ 返回: "香港 01" (字符串)
首页
  ↓ 创建占位符节点: example.com
配置生成
  ↓ 使用占位符节点
❌ 配置文件: server = "example.com"
```

### 修改后的流程

```
节点选择页面
  ↓ 返回: NodeModel 对象 (完整数据)
首页
  ↓ 直接使用返回的节点
配置生成
  ↓ 使用真实节点数据
✅ 配置文件: server = "hyld.jsyd.plnode.xyz"
```

## 代码修改

### 1. 节点选择页面 (`node_selection_page.dart`)

**返回类型改为 `NodeModel?`**：
```dart
static Future<NodeModel?> show(...) async {
  return await showModalBottomSheet<NodeModel>(...);
}
```

**关闭时返回节点对象**：
```dart
Navigator.pop(context, node['nodeModel'] as NodeModel?);
```

### 2. 首页 (`home_page.dart`)

**接收返回的节点对象**：
```dart
final selectedNodeModel = await NodeSelectionPage.show(...);

if (selectedNodeModel != null) {
  setState(() {
    _selectedNodeModel = selectedNodeModel;
  });
}
```

**移除占位符节点创建**：
```dart
// ❌ 删除
_selectedNodeModel = NodeModel(
  rawConfig: 'hysteria2://...@example.com:443...',
);

// ✅ 改为
if (_selectedNodeModel == null) {
  _showError('请先选择节点');
  return;
}
```

## 节点持久化

### 保存节点
```dart
// 在节点选择页面，用户点击节点后
await NodeStorageService.saveSelectedNode(nodeModel);
```

### 加载节点
```dart
// 首页初始化或连接时
final savedNode = await NodeStorageService.getSelectedNode();
if (savedNode != null) {
  _selectedNodeModel = savedNode;
}
```

## 数据流

### 完整的节点数据流

```
1. 用户登录
   ↓
2. 获取订阅信息 (UUID)
   ↓
3. 获取节点列表 (API)
   ↓ 解析节点 URL
4. 显示节点列表 (NodeModel 列表)
   ↓ 用户选择
5. 返回 NodeModel 对象
   ↓
6. 保存到 SharedPreferences
   ↓
7. 生成 sing-box 配置
   ↓ 包含真实服务器地址
8. 启动 sing-box
   ✅ 成功连接！
```

## 现在的工作流程

### 首次使用
1. 用户打开应用
2. 点击"节点选择"
3. 选择一个节点（如"🇭🇰 香港|01"）
4. 节点数据保存到本地
5. 点击"连接"按钮
6. ✅ 使用真实节点连接

### 后续使用
1. 用户打开应用
2. 自动加载上次保存的节点
3. 点击"连接"按钮
4. ✅ 直接连接，无需重新选择

## 验证方法

### 1. 查看应用日志
```
📌 使用保存的节点: 🇭🇰 香港|01|0.8x
📝 正在为节点生成配置: 🇭🇰 香港|01|0.8x
   协议: Hysteria2
   代理模式: 绕过大陆
```

### 2. 查看配置文件
```json
{
  "outbounds": [
    {
      "tag": "proxy",
      "server": "hyld.jsyd.plnode.xyz",  // ✅ 真实服务器地址
      "server_port": 58659,
      "type": "hysteria2"
    }
  ]
}
```

### 3. 测试连接
- 选择一个节点
- 点击连接
- 检查日志是否有 DNS 错误
- 检查是否能访问外网

## 相关文件

- `lib/pages/node_selection_page.dart` - 节点选择页面
- `lib/pages/home_page.dart` - 首页（连接逻辑）
- `lib/services/node_storage_service.dart` - 节点持久化
- `lib/utils/node_config_converter.dart` - 配置生成
- `lib/models/node_model.dart` - 节点数据模型

## 注意事项

1. **必须先选择节点**：首次使用必须先选择一个节点
2. **节点会自动保存**：选择后会自动保存，下次直接使用
3. **可以随时更换**：在节点选择页面选择新节点即可
4. **数据持久化**：节点数据保存在 SharedPreferences 中

