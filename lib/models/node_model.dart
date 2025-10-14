import 'dart:convert';

/// 节点数据模型
class NodeModel {
  final String name;         // 节点名称
  final String protocol;     // 协议类型（hysteria2/vmess/vless等）
  final String location;     // 节点位置
  final String rawConfig;    // 原始配置字符串
  final String? rate;        // 倍率（如果有）
  final String type;         // 节点类型（premium/auto等）

  NodeModel({
    required this.name,
    required this.protocol,
    required this.location,
    required this.rawConfig,
    this.rate,
    this.type = 'premium',
  });

  /// 从订阅URL行解析节点
  static NodeModel? fromSubscriptionLine(String line) {
    try {
      if (line.trim().isEmpty) return null;

      String protocol = '';
      String name = '';
      String location = '';
      String? rate;

      // 判断协议类型
      if (line.startsWith('hysteria2://')) {
        protocol = 'Hysteria2';
        // Hysteria2 节点名称在#后面
        if (line.contains('#')) {
          final parts = line.split('#');
          if (parts.length > 1) {
            name = Uri.decodeComponent(parts[1]);
          }
        }
      } else if (line.startsWith('vmess://')) {
        protocol = 'VMess';
        // VMess 节点配置在 vmess:// 后面的Base64编码中
        final base64Part = line.substring('vmess://'.length);
        try {
          // 使用标准库解码Base64和JSON
          final decoded = utf8.decode(base64.decode(base64Part));
          final config = json.decode(decoded) as Map<String, dynamic>;
          
          if (config['ps'] != null) {
            // ps 字段是节点名称，json.decode已经自动处理了Unicode转义
            name = config['ps'].toString();
          }
        } catch (e) {
          // 解码失败，尝试从#后面获取（如果有）
          if (line.contains('#')) {
            final parts = line.split('#');
            if (parts.length > 1) {
              name = Uri.decodeComponent(parts[1]);
            }
          }
        }
      } else if (line.startsWith('vless://')) {
        protocol = 'VLESS';
        // VLESS 节点名称在#后面
        if (line.contains('#')) {
          final parts = line.split('#');
          if (parts.length > 1) {
            name = Uri.decodeComponent(parts[1]);
          }
        }
      } else if (line.startsWith('trojan://')) {
        protocol = 'Trojan';
        if (line.contains('#')) {
          final parts = line.split('#');
          if (parts.length > 1) {
            name = Uri.decodeComponent(parts[1]);
          }
        }
      } else if (line.startsWith('ss://')) {
        protocol = 'Shadowsocks';
        if (line.contains('#')) {
          final parts = line.split('#');
          if (parts.length > 1) {
            name = Uri.decodeComponent(parts[1]);
          }
        }
      } else {
        return null; // 不支持的协议
      }

      // 如果名称为空，使用协议作为名称
      if (name.isEmpty) {
        name = protocol;
      }

      // 从名称中提取位置信息
      location = _extractLocation(name);

      // 从名称中提取倍率信息
      rate = _extractRate(name);

      return NodeModel(
        name: name,
        protocol: protocol,
        location: location.isNotEmpty ? location : '未知',
        rawConfig: line,
        rate: rate,
      );
    } catch (e) {
      // 解析失败时输出错误信息
      return null;
    }
  }

  /// 从订阅内容解析所有节点
  static List<NodeModel> parseSubscriptionContent(String content) {
    final nodes = <NodeModel>[];
    
    // 按行分割
    final lines = content.split('\n');
    
    for (final line in lines) {
      final node = fromSubscriptionLine(line.trim());
      if (node != null) {
        nodes.add(node);
      }
    }
    
    return nodes;
  }

  /// 提取位置信息
  static String _extractLocation(String name) {
    // 常见的国家/地区映射
    final locationMap = {
      '香港': '香港',
      'HK': '香港',
      '🇭🇰': '香港',
      '台湾': '台湾',
      'TW': '台湾',
      '🇹🇼': '台湾',
      '新加坡': '新加坡',
      'SG': '新加坡',
      '🇸🇬': '新加坡',
      '日本': '日本',
      'JP': '日本',
      '🇯🇵': '日本',
      '韩国': '韩国',
      'KR': '韩国',
      '🇰🇷': '韩国',
      '美国': '美国',
      'US': '美国',
      '🇺🇸': '美国',
      '英国': '英国',
      'UK': '英国',
      '🇬🇧': '英国',
      '德国': '德国',
      'DE': '德国',
      '🇩🇪': '德国',
      '法国': '法国',
      'FR': '法国',
      '🇫🇷': '法国',
      '加拿大': '加拿大',
      'CA': '加拿大',
      '🇨🇦': '加拿大',
      '澳大利亚': '澳大利亚',
      'AU': '澳大利亚',
      '🇦🇺': '澳大利亚',
      '印度': '印度',
      'IN': '印度',
      '🇮🇳': '印度',
      '俄罗斯': '俄罗斯',
      'RU': '俄罗斯',
      '🇷🇺': '俄罗斯',
      '巴西': '巴西',
      'BR': '巴西',
      '🇧🇷': '巴西',
      '沙特': '沙特',
      'SA': '沙特',
      '🇸🇦': '沙特',
      '阿根廷': '阿根廷',
      'AR': '阿根廷',
      '🇦🇷': '阿根廷',
      '瑞典': '瑞典',
      'SE': '瑞典',
      '🇸🇪': '瑞典',
      '波兰': '波兰',
      'PL': '波兰',
      '🇵🇱': '波兰',
      '土耳其': '土耳其',
      'TR': '土耳其',
      '🇹🇷': '土耳其',
      '菲律宾': '菲律宾',
      'PH': '菲律宾',
      '🇵🇭': '菲律宾',
      '泰国': '泰国',
      'TH': '泰国',
      '🇹🇭': '泰国',
      '越南': '越南',
      'VN': '越南',
      '🇻🇳': '越南',
      '马来西亚': '马来西亚',
      'MY': '马来西亚',
      '🇲🇾': '马来西亚',
    };

    for (final entry in locationMap.entries) {
      if (name.contains(entry.key)) {
        return entry.value;
      }
    }

    return '';
  }

  /// 提取倍率信息
  static String? _extractRate(String name) {
    // 匹配类似 "0.8x" "1.0x" "1.6x" 的倍率
    final rateRegex = RegExp(r'(\d+\.?\d*)x', caseSensitive: false);
    final match = rateRegex.firstMatch(name);
    if (match != null && match.groupCount > 0) {
      return match.group(1);
    }
    return null;
  }

  /// 获取显示名称（去除协议前缀等）
  String get displayName {
    // 移除 [Hy2] [vmess] [vless] 等前缀
    String cleaned = name.replaceAll(RegExp(r'\[(Hy2|vmess|vless|trojan|ss)\]\s*', caseSensitive: false), '');
    return cleaned;
  }

  /// 获取节点颜色（根据倍率）
  String get colorCode {
    if (rate != null) {
      final rateValue = double.tryParse(rate!) ?? 1.0;
      if (rateValue <= 0.8) {
        return '#4CAF50'; // 绿色 - 低倍率
      } else if (rateValue <= 1.2) {
        return '#FF9800'; // 橙色 - 中倍率
      } else {
        return '#F44336'; // 红色 - 高倍率
      }
    }
    return '#007AFF'; // 默认蓝色
  }
}

