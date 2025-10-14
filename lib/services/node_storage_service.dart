import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/node_model.dart';

/// 节点存储服务
/// 用于保存和读取用户选择的节点信息
class NodeStorageService {
  static const String _keySelectedNodeName = 'selected_node_name';
  static const String _keySelectedNodeData = 'selected_node_data';
  
  /// 保存选中的节点
  static Future<void> saveSelectedNode(NodeModel node) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 保存节点名称
      await prefs.setString(_keySelectedNodeName, node.name);
      
      // 保存节点完整数据（JSON格式）
      final nodeJson = jsonEncode({
        'name': node.name,
        'protocol': node.protocol,
        'location': node.location,
        'rawConfig': node.rawConfig,
        'rate': node.rate,
        'type': node.type,
      });
      
      await prefs.setString(_keySelectedNodeData, nodeJson);
      
      print('💾 已保存节点: ${node.name}');
    } catch (e) {
      print('❌ 保存节点失败: $e');
    }
  }
  
  /// 获取上次选中的节点名称
  static Future<String?> getSelectedNodeName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keySelectedNodeName);
    } catch (e) {
      print('❌ 读取节点名称失败: $e');
      return null;
    }
  }
  
  /// 获取上次选中的节点完整数据
  static Future<NodeModel?> getSelectedNode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nodeJson = prefs.getString(_keySelectedNodeData);
      
      if (nodeJson == null) return null;
      
      final nodeMap = jsonDecode(nodeJson) as Map<String, dynamic>;
      
      return NodeModel(
        name: nodeMap['name'] ?? '',
        protocol: nodeMap['protocol'] ?? '',
        location: nodeMap['location'] ?? '',
        rawConfig: nodeMap['rawConfig'] ?? '',
        rate: nodeMap['rate'],
        type: nodeMap['type'] ?? 'premium',
      );
    } catch (e) {
      print('❌ 读取节点数据失败: $e');
      return null;
    }
  }
  
  /// 清除节点选择
  static Future<void> clearSelectedNode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySelectedNodeName);
      await prefs.remove(_keySelectedNodeData);
      print('🗑️ 已清除节点选择');
    } catch (e) {
      print('❌ 清除节点失败: $e');
    }
  }
  
  /// 检查是否有保存的节点
  static Future<bool> hasSelectedNode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_keySelectedNodeName);
    } catch (e) {
      return false;
    }
  }
  
  /// 获取 SharedPreferences 实例（供其他功能使用）
  static Future<SharedPreferences> getPreferences() async {
    return await SharedPreferences.getInstance();
  }
}

