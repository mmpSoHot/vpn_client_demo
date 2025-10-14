import 'dart:convert';
import '../models/node_model.dart';

/// 节点配置转换器
/// 将不同协议的节点URL转换为 Sing-box 配置格式
class NodeConfigConverter {
  
  /// 将节点转换为 Sing-box outbound 配置
  static Map<String, dynamic>? convertToOutbound(NodeModel node) {
    if (node.protocol == 'Hysteria2') {
      return _convertHysteria2(node);
    } else if (node.protocol == 'VMess') {
      return _convertVMess(node);
    } else if (node.protocol == 'VLESS') {
      return _convertVLESS(node);
    }
    
    return null;
  }

  /// 转换 Hysteria2 节点
  static Map<String, dynamic>? _convertHysteria2(NodeModel node) {
    try {
      // 解析 hysteria2://uuid@server:port?params#name
      final uri = Uri.parse(node.rawConfig);
      
      // 提取 UUID（在 @ 之前）
      final userInfo = uri.userInfo;
      
      // 提取服务器和端口
      final server = uri.host;
      final port = uri.port;
      
      // 解析查询参数
      final params = uri.queryParameters;
      final sni = params['sni'];
      final insecure = params['insecure'] == '1';
      
      return {
        "type": "hysteria2",
        "tag": node.displayName,
        "server": server,
        "server_port": port,
        "password": userInfo,
        "tls": {
          "enabled": true,
          "server_name": sni ?? server,
          "insecure": insecure,
        }
      };
    } catch (e) {
      print('解析 Hysteria2 节点失败: $e');
      return null;
    }
  }

  /// 转换 VMess 节点
  static Map<String, dynamic>? _convertVMess(NodeModel node) {
    try {
      // VMess 格式: vmess://base64(json)
      final base64Part = node.rawConfig.substring('vmess://'.length);
      final decoded = utf8.decode(base64.decode(base64Part));
      final config = json.decode(decoded) as Map<String, dynamic>;
      
      final server = config['add'] as String;
      final port = int.tryParse(config['port'].toString()) ?? 0;
      final uuid = config['id'] as String;
      final aid = int.tryParse(config['aid']?.toString() ?? '0') ?? 0;
      final network = config['net'] as String? ?? 'tcp';
      final tls = config['tls'] as String? ?? '';
      final host = config['host'] as String? ?? '';
      final path = config['path'] as String? ?? '';
      final sni = config['sni'] as String? ?? '';
      
      final outbound = {
        "type": "vmess",
        "tag": node.displayName,
        "server": server,
        "server_port": port,
        "uuid": uuid,
        "alter_id": aid,
        "security": "auto",
      };

      // TLS 配置
      if (tls.isNotEmpty && tls != '0') {
        outbound["tls"] = {
          "enabled": true,
          "server_name": sni.isNotEmpty ? sni : (host.isNotEmpty ? host : server),
          "insecure": false,
        };
      }

      // 传输层配置
      if (network != 'tcp') {
        final transport = <String, dynamic>{
          "type": network,
        };
        
        if (network == 'ws') {
          transport["path"] = path.isNotEmpty ? path : '/';
          if (host.isNotEmpty) {
            transport["headers"] = {"Host": host};
          }
        } else if (network == 'grpc') {
          transport["service_name"] = path;
        }
        
        outbound["transport"] = transport;
      }

      return outbound;
    } catch (e) {
      print('解析 VMess 节点失败: $e');
      return null;
    }
  }

  /// 转换 VLESS 节点
  static Map<String, dynamic>? _convertVLESS(NodeModel node) {
    try {
      // 解析 vless://uuid@server:port?params#name
      final uri = Uri.parse(node.rawConfig);
      
      final uuid = uri.userInfo;
      final server = uri.host;
      final port = uri.port;
      
      final params = uri.queryParameters;
      // final encryption = params['encryption'] ?? 'none'; // VLESS encryption 通常为 none
      final flow = params['flow'] ?? '';
      final security = params['security'] ?? '';
      final sni = params['sni'] ?? '';
      final type = params['type'] ?? 'tcp';
      final path = params['path'] ?? '';
      final host = params['host'] ?? '';
      
      final outbound = {
        "type": "vless",
        "tag": node.displayName,
        "server": server,
        "server_port": port,
        "uuid": uuid,
      };

      // Flow
      if (flow.isNotEmpty) {
        outbound["flow"] = flow;
      }

      // TLS 配置
      if (security == 'tls' || security == 'reality') {
        outbound["tls"] = {
          "enabled": true,
          "server_name": sni.isNotEmpty ? sni : server,
          "insecure": false,
        };
      }

      // 传输层配置
      if (type != 'tcp') {
        final transport = <String, dynamic>{
          "type": type,
        };
        
        if (type == 'ws') {
          transport["path"] = path.isNotEmpty ? path : '/';
          if (host.isNotEmpty) {
            transport["headers"] = {"Host": host};
          }
        } else if (type == 'grpc') {
          transport["service_name"] = path;
        }
        
        outbound["transport"] = transport;
      }

      return outbound;
    } catch (e) {
      print('解析 VLESS 节点失败: $e');
      return null;
    }
  }

  /// 生成完整的 Sing-box 配置
  static Map<String, dynamic> generateFullConfig({
    required NodeModel node,
    int mixedPort = 15808,
    bool enableTun = false,
  }) {
    final outbound = convertToOutbound(node);
    
    if (outbound == null) {
      throw Exception('不支持的节点协议: ${node.protocol}');
    }

    return {
      "log": {
        "level": "info",
        "timestamp": true
      },
      "dns": {
        "servers": [
          {
            "tag": "google",
            "server": "8.8.8.8",
            "type": "udp"
          },
          {
            "tag": "local",
            "server": "223.5.5.5",
            "type": "udp"
          }
        ],
        "final": "google",
        "strategy": "prefer_ipv4"
      },
      "inbounds": enableTun ? _getTunInbounds() : _getMixedInbounds(mixedPort),
      "outbounds": [
        outbound, // 代理节点
        {
          "type": "direct",
          "tag": "direct"
        },
        {
          "type": "block",
          "tag": "block"
        }
      ],
      "route": {
        "default_domain_resolver": {
          "server": "google",
          "strategy": "prefer_ipv4"
        },
        "rules": [
          {
            "action": "sniff"
          },
          {
            "protocol": "dns",
            "action": "hijack-dns"
          },
          {
            "ip_is_private": true,
            "outbound": "direct"
          }
        ],
        "final": outbound["tag"],
        "auto_detect_interface": true
      }
    };
  }

  /// 获取 Mixed 入站配置
  static List<Map<String, dynamic>> _getMixedInbounds(int port) {
    return [
      {
        "type": "mixed",
        "tag": "mixed-in",
        "listen": "127.0.0.1",
        "listen_port": port,
        "sniff": true,
        "sniff_override_destination": false
      }
    ];
  }

  /// 获取 TUN 入站配置
  static List<Map<String, dynamic>> _getTunInbounds() {
    return [
      {
        "type": "tun",
        "tag": "tun-in",
        "inet4_address": "172.19.0.1/30",
        "auto_route": true,
        "strict_route": true,
        "sniff": true,
        "sniff_override_destination": false
      }
    ];
  }
}

