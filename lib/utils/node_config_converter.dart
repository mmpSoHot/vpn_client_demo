import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/node_model.dart';
import '../services/proxy_mode_service.dart';

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

  /// 转换 Hysteria2 节点 (参照 NekoBoxForAndroid)
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
      final obfsPassword = params['obfs-password'];
      
      final config = {
        "type": "hysteria2",
        "tag": node.displayName,
        "server": server,
        "server_port": port,
        "up_mbps": 100,  // 上行带宽 (必需!)
        "down_mbps": 100,  // 下行带宽 (必需!)
        "password": userInfo,
        "tls": {
          "enabled": true,
          "server_name": sni ?? server,
          "alpn": ["h3"],  // Hysteria2 必须使用 h3
          "insecure": insecure,
        }
      };
      
      // 混淆配置
      if (obfsPassword != null && obfsPassword.isNotEmpty) {
        config["obfs"] = {
          "type": "salamander",
          "password": obfsPassword
        };
      }
      
      return config;
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
      
      print('📝 VMess 节点解析:');
      print('   服务器: $server:$port');
      print('   传输: $network, TLS: ${tls.isNotEmpty ? "是" : "否"}');
      
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
      // final encryption = params['encryption'] ?? 'none'; // VLESS 默认不加密
      final flow = params['flow'] ?? '';
      final security = params['security'] ?? '';
      final sni = params['sni'] ?? '';
      final type = params['type'] ?? 'tcp';
      final path = params['path'] ?? '';
      final host = params['host'] ?? '';
      final mode = params['mode'] ?? '';
      
      print('📝 VLESS 节点解析:');
      print('   服务器: $server:$port');
      print('   Flow: ${flow.isNotEmpty ? flow : "无"}');
      print('   Mode: ${mode.isNotEmpty ? mode : "无"}');
      print('   传输: $type, TLS: ${security.isNotEmpty ? "是" : "否"}');
      
      final outbound = {
        "type": "vless",
        "tag": node.displayName,
        "server": server,
        "server_port": port,
        "uuid": uuid,
      };

      // Flow（VLESS 特有）
      if (flow.isNotEmpty) {
        outbound["flow"] = flow;
      }
      
      // Packet encoding（VLESS 特有）
      if (mode.isNotEmpty) {
        if (mode == 'multi') {
          outbound["packet_encoding"] = "xudp";
        } else {
          outbound["packet_encoding"] = mode;
        }
      }

      // TLS 配置
      if (security == 'tls' || security == 'reality') {
        final tlsConfig = {
          "enabled": true,
          "server_name": sni.isNotEmpty ? sni : server,
          "insecure": false,
        };
        
        // 如果没有使用 flow，添加 record_fragment
        if (flow.isEmpty) {
          tlsConfig["record_fragment"] = false;
        }
        
        outbound["tls"] = tlsConfig;
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
    bool enableStatsApi = true,
    ProxyMode proxyMode = ProxyMode.bypassCN,
  }) {
    final outbound = convertToOutbound(node);
    
    if (outbound == null) {
      throw Exception('不支持的节点协议: ${node.protocol}');
    }

    // 根据代理模式生成配置
    if (proxyMode == ProxyMode.bypassCN) {
      return _generateBypassCNConfig(node, outbound, mixedPort, enableTun, enableStatsApi);
    } else {
      return _generateGlobalConfig(node, outbound, mixedPort, enableTun, enableStatsApi);
    }
  }

  /// 生成绕过大陆模式配置
  static Map<String, dynamic> _generateBypassCNConfig(
    NodeModel node,
    Map<String, dynamic> outbound,
    int mixedPort,
    bool enableTun,
    bool enableStatsApi,
  ) {
    // 设置 tag 为 proxy
    outbound["tag"] = "proxy";
    
    final config = {
      "log": {
        "level": "debug",
        "timestamp": true
      },
      "dns": _getBypassCNDnsConfig(node),
      "inbounds": enableTun ? _getTunInbounds() : _getMixedInbounds(mixedPort),
      "outbounds": [
        outbound,
        {
          "type": "direct",
          "tag": "direct"
        },
        {
          "type": "direct",
          "tag": "bypass"
        },
        {
          "type": "block",
          "tag": "block"
        }
      ],
      "route": _getBypassCNRouteConfig(),
    };

    // 添加 experimental 配置
    final experimentalConfig = _getExperimentalConfig(enableStatsApi);
    if (experimentalConfig.isNotEmpty) {
      config["experimental"] = experimentalConfig;
    }

    return config;
  }

  /// 生成全局代理模式配置
  static Map<String, dynamic> _generateGlobalConfig(
    NodeModel node,
    Map<String, dynamic> outbound,
    int mixedPort,
    bool enableTun,
    bool enableStatsApi,
  ) {
    // 设置 tag 为 proxy
    outbound["tag"] = "proxy";
    
    final config = {
      "log": {
        "level": "debug",
        "timestamp": true
      },
      "dns": _getGlobalDnsConfig(node),
      "inbounds": enableTun ? _getTunInbounds() : _getMixedInbounds(mixedPort),
      "outbounds": [
        outbound,
        {
          "type": "direct",
          "tag": "direct"
        },
        {
          "type": "direct",
          "tag": "bypass"
        },
        {
          "type": "block",
          "tag": "block"
        }
      ],
      "route": _getGlobalRouteConfig(),
    };

    // 添加 experimental 配置
    final experimentalConfig = _getExperimentalConfig(enableStatsApi);
    if (experimentalConfig.isNotEmpty) {
      config["experimental"] = experimentalConfig;
    }

    return config;
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

  /// 获取 TUN 入站配置 (参照 NekoBoxForAndroid)
  static List<Map<String, dynamic>> _getTunInbounds() {
    return [
      {
        "type": "tun",
        "tag": "tun-in",
        "inet4_address": "172.19.0.1/30",
        "inet6_address": "fdfe:dcba:9876::1/126",
        "mtu": 1400,  // 降低 MTU,避免分片问题
        "auto_route": true,
        "strict_route": true,
        "stack": "mixed",  // 或 gvisor/system
        "endpoint_independent_nat": true,
        "sniff": true,
        "sniff_override_destination": false
      }
    ];
  }

  /// 获取绕过大陆的 DNS 配置
  static Map<String, dynamic> _getBypassCNDnsConfig(NodeModel node) {
    // Android 使用简化 DNS 配置
    if (Platform.isAndroid) {
      return _getAndroidBypassCNDnsConfig(node);
    }
    
    final server = _extractServerFromNode(node);
    
    return {
      "servers": [
        {
          "server": "223.5.5.5",
          "type": "udp",
          "tag": "final_resolver"
        },
        {
          "server": "8.8.8.8",
          "type": "udp",
          "tag": "remote_dns",
          "detour": "proxy"
        },
        {
          "server": "223.5.5.5",
          "type": "udp",
          "tag": "direct_dns"
        },
        {
          "server": "223.5.5.5",
          "type": "udp",
          "tag": "outbound_resolver"
        },
      ],
      "rules": [
        {
          "server": "outbound_resolver",
          "domain": [server]
        },
        {
          "server": "direct_dns",
          "rule_set": ["geosite-private"]
        },
        {
          "server": "remote_dns",
          "rule_set": ["geosite-gfw"]
        },
        {
          "server": "direct_dns",
          "rule_set": ["geosite-geolocation-cn"]
        }
      ],
      "final": "remote_dns",
      "independent_cache": true
    };
  }

  /// 获取全局代理的 DNS 配置
  static Map<String, dynamic> _getGlobalDnsConfig(NodeModel node) {
    // Android 使用简化 DNS 配置
    if (Platform.isAndroid) {
      return _getAndroidGlobalDnsConfig(node);
    }
    
    final server = _extractServerFromNode(node);
    
    return {
      "servers": [
        {
          "server": "223.5.5.5",
          "type": "udp",
          "tag": "final_resolver"
        },
        {
          "server": "8.8.8.8",
          "type": "udp",
          "tag": "remote_dns",
          "detour": "proxy"
        },
        {
          "server": "223.5.5.5",
          "type": "udp",
          "tag": "direct_dns"
        },
        {
          "server": "223.5.5.5",
          "type": "udp",
          "tag": "outbound_resolver"
        },
      ],
      "rules": [
        {
          "server": "outbound_resolver",
          "domain": [server]
        },
        {
          "server": "direct_dns",
          "rule_set": ["geosite-private"]
        }
      ],
      "final": "remote_dns",
      "independent_cache": true
    };
  }
  /// 获取绕过大陆的路由配置
  static Map<String, dynamic> _getBypassCNRouteConfig() {
    // Android 使用简化配置(不依赖本地规则文件)
    if (Platform.isAndroid) {
      return _getAndroidBypassCNRouteConfig();
    }
    
    // 获取 geosite 规则文件路径
    final String geoRuleBasePath = _getGeoRuleBasePath();
    
    return {
      "default_domain_resolver": {
        "server": "outbound_resolver",
        "strategy": ""
      },
      "rules": [
        {"action": "sniff"},
        {"protocol": ["dns"], "action": "hijack-dns"},
        {"domain": [], "action": "resolve"},
        {"outbound": "direct", "clash_mode": "Direct"},
        {"outbound": "proxy", "clash_mode": "Global"},
        {
          "outbound": "proxy",
          "domain": ["googleapis.cn", "gstatic.com"],
          "domain_suffix": [".googleapis.cn", ".gstatic.com"]
        },
        {"network": ["udp"], "port": [443], "action": "reject"},
        {"outbound": "direct", "ip_is_private": true},
        {"outbound": "direct", "rule_set": ["geosite-private"]},
        {
          "outbound": "direct",
          "ip_cidr": [
            "223.5.5.5", "223.6.6.6", "2400:3200::1", "2400:3200:baba::1",
            "119.29.29.29", "1.12.12.12", "120.53.53.53", "2402:4e00::", "2402:4e00:1::",
            "180.76.76.76", "2400:da00::6666", "114.114.114.114", "114.114.115.115",
            "114.114.114.119", "114.114.115.119", "114.114.114.110", "114.114.115.110",
            "180.184.1.1", "180.184.2.2", "101.226.4.6", "218.30.118.6",
            "123.125.81.6", "140.207.198.6", "1.2.4.8", "210.2.4.8",
            "52.80.66.66", "117.50.22.22", "2400:7fc0:849e:200::4", "2404:c2c0:85d8:901::4",
            "117.50.10.10", "52.80.52.52", "2400:7fc0:849e:200::8", "2404:c2c0:85d8:901::8",
            "117.50.60.30", "52.80.60.30"
          ]
        },
        {
          "outbound": "direct",
          "domain": ["alidns.com", "doh.pub", "dot.pub", "360.cn", "onedns.net"],
          "domain_suffix": [".alidns.com", ".doh.pub", ".dot.pub", ".360.cn", ".onedns.net"]
        },
        {"outbound": "proxy", "rule_set": ["geosite-gfw"]},
        {"outbound": "direct", "rule_set": ["geoip-cn"]},
        {"outbound": "direct", "rule_set": ["geosite-geolocation-cn"]}
      ],
      "rule_set": [
        {
          "tag": "geosite-private",
          "type": "local",
          "format": "binary",
          "path": "$geoRuleBasePath/geosite/geosite-private.srs"
        },
        {
          "tag": "geosite-gfw",
          "type": "local",
          "format": "binary",
          "path": "$geoRuleBasePath/geosite/geosite-gfw.srs"
        },
        {
          "tag": "geosite-geolocation-cn",
          "type": "local",
          "format": "binary",
          "path": "$geoRuleBasePath/geosite/geosite-geolocation-cn.srs"
        },
        {
          "tag": "geoip-cn",
          "type": "local",
          "format": "binary",
          "path": "$geoRuleBasePath/geoip/geoip-cn.srs"
        }
      ],
      "final": "proxy"
    };
  }

  /// 获取全局代理的路由配置
  static Map<String, dynamic> _getGlobalRouteConfig() {
    // Android 使用简化配置(不依赖本地规则文件)
    if (Platform.isAndroid) {
      return _getAndroidGlobalRouteConfig();
    }
    
    // 获取 geosite 规则文件路径
    final String geoRuleBasePath = _getGeoRuleBasePath();
    
    return {
      "default_domain_resolver": {
        "server": "outbound_resolver",
        "strategy": ""
      },
      "rules": [
        {"action": "sniff"},
        {"protocol": ["dns"], "action": "hijack-dns"},
        {"domain": [], "action": "resolve"},
        {"outbound": "direct", "clash_mode": "Direct"},
        {"outbound": "proxy", "clash_mode": "Global"},
        {"network": ["udp"], "port": [443], "action": "reject"},
        {"outbound": "direct", "ip_is_private": true},
        {"outbound": "direct", "rule_set": ["geosite-private"]},
        {"outbound": "proxy", "port_range": ["0:65535"]}
      ],
      "rule_set": [
        {
          "tag": "geosite-private",
          "type": "local",
          "format": "binary",
          "path": "$geoRuleBasePath/geosite/geosite-private.srs"
        }
      ],
      "final": "proxy"
    };
  }

  /// 获取 experimental 配置
  static Map<String, dynamic> _getExperimentalConfig(bool enableStatsApi) {
    final config = <String, dynamic>{};
    
    // Android/iOS: 需要指定可写路径
    if (Platform.isAndroid || Platform.isIOS) {
      // sing-box-dev-next 在 Android 上有 chown 权限问题
      // 暂时禁用 cache_file,等待 stable 版本修复
      // 但 clash_api 可以正常使用
      if (enableStatsApi) {
        config["clash_api"] = {
          "external_controller": "127.0.0.1:9090",
          "external_ui": "",
          "secret": ""
        };
      }
      return config;
    }
    
    // Windows/macOS/Linux: 完整配置
    final cacheDbPath = _getCacheDbPath();
    if (cacheDbPath.isNotEmpty) {
      config["cache_file"] = {
        "enabled": true,
        "path": cacheDbPath,
        "store_fakeip": false
      };
    }
    
    // API 配置
    if (enableStatsApi) {
      config["clash_api"] = {
        "external_controller": "127.0.0.1:9090",
        "external_ui": "",
        "secret": ""
      };
    }
    
    return config;
  }

  /// 从节点提取服务器地址
  static String _extractServerFromNode(NodeModel node) {
    try {
      final uri = Uri.parse(node.rawConfig);
      return uri.host;
    } catch (e) {
      print('提取服务器地址失败: $e');
      return "unknown.server.com";
    }
  }

  /// Android 绕过大陆 DNS 配置 (参照 sing-box-for-android)
  static Map<String, dynamic> _getAndroidBypassCNDnsConfig(NodeModel node) {
    final server = _extractServerFromNode(node);
    
    print('📝 Android DNS 配置 - 代理服务器: $server');
    
    return {
      "servers": [
        // 1. 国内 DNS (直连) - 用于国内域名和代理服务器
        {
          "tag": "dns-direct",
          "address": "223.5.5.5",
          "detour": "direct"
        },
        // 2. 国外 DNS (走代理) - 用于国外域名
        {
          "tag": "dns-remote",
          "address": "8.8.8.8",
          "detour": "proxy"
        },
      ],
      "rules": [
        // 1. 代理服务器域名用 direct DNS (避免循环)
        {
          "domain": [server],
          "server": "dns-direct"
        },
        // 2. 私有域名用 direct DNS
        {
          "rule_set": ["geosite-private"],
          "server": "dns-direct"
        },
        // 3. 被墙网站用 remote DNS (走代理解析)
        {
          "rule_set": ["geosite-gfw"],
          "server": "dns-remote"
        },
        // 4. 国内域名用 direct DNS
        {
          "rule_set": ["geosite-geolocation-cn"],
          "server": "dns-direct"
        },
      ],
      "final": "dns-remote"
    };
  }

  /// Android 全局代理 DNS 配置 (参照 sing-box-for-android)
  static Map<String, dynamic> _getAndroidGlobalDnsConfig(NodeModel node) {
    final server = _extractServerFromNode(node);
    
    return {
      "servers": [
        // 1. 国内 DNS (直连) - 用于代理服务器域名
        {
          "tag": "dns-direct",
          "address": "223.5.5.5",
          "detour": "direct"
        },
        // 2. 国外 DNS (走代理) - 用于其他域名
        {
          "tag": "dns-remote",
          "address": "8.8.8.8",
          "detour": "proxy"
        },
      ],
      "rules": [
        // 1. 代理服务器域名用 direct DNS (避免循环)
        {
          "domain": [server],
          "server": "dns-direct"
        }
      ],
      "final": "dns-remote"
    };
  }

  /// Android 绕过大陆配置 (完全参照 NekoBoxForAndroid)
  static Map<String, dynamic> _getAndroidBypassCNRouteConfig() {
    return {
      "auto_detect_interface": true,
      "rules": [
        // 0. DNS 劫持（使用 action，让 sing-box DNS 处理）
        {
          "protocol": ["dns"],
          "action": "hijack-dns"
        },
        // 1. 局域网 IP 直连（排除 TUN DNS）
        {
          "ip_cidr": [
            "192.168.0.0/16",
            "10.0.0.0/8", 
            "172.16.0.0/12",
            "127.0.0.0/8",
            "169.254.0.0/16"
          ],
          "outbound": "direct"
        },
        // 2. 私有 IP 直连 (使用 rule_set)
        {
          "rule_set": ["geosite-private"],
          "outbound": "bypass"
        },
        // 3. 被墙网站走代理 (关键！优先级高)
        {
          "rule_set": ["geosite-gfw"],
          "outbound": "proxy"
        },
        // 4. 国内域名直连 (使用更准确的 geolocation-cn)
        {
          "rule_set": ["geosite-geolocation-cn"],
          "outbound": "bypass"
        },
        // 5. 国内 IP 直连 (使用 rule_set)
        {
          "rule_set": ["geoip-cn"],
          "outbound": "bypass"
        }
      ],
      "rule_set": [
        {
          "tag": "geosite-private",
          "type": "local",
          "format": "binary",
          "path": "geosite-private.srs"  // 使用相对路径,sing-box 会在 working directory 查找
        },
        {
          "tag": "geosite-gfw",
          "type": "local",
          "format": "binary",
          "path": "geosite-gfw.srs"
        },
        {
          "tag": "geosite-geolocation-cn",
          "type": "local",
          "format": "binary",
          "path": "geosite-geolocation-cn.srs"
        },
        {
          "tag": "geoip-cn",
          "type": "local",
          "format": "binary",
          "path": "geoip-cn.srs"
        }
      ],
      "final": "proxy"
    };
  }

  /// Android 全局代理配置 (不使用本地规则文件)
  static Map<String, dynamic> _getAndroidGlobalRouteConfig() {
    return {
      "auto_detect_interface": true,
      "rules": [
        // 0. DNS 劫持（使用 action，让 sing-box DNS 处理）
        {
          "protocol": ["dns"],
          "action": "hijack-dns"
        },
        // 1. 局域网 IP 直连
        {
          "ip_cidr": [
            "192.168.0.0/16",
            "10.0.0.0/8",
            "172.16.0.0/12",
            "127.0.0.0/8",
            "169.254.0.0/16"
          ],
          "outbound": "direct"
        }
      ],
      "final": "proxy"
    };
  }

  /// 获取 geo 规则文件基础路径
  static String _getGeoRuleBasePath() {
    // Android 暂不支持本地规则文件（使用相对路径）
    if (Platform.isAndroid) {
      return '/data/local/tmp/assets/datas';  // 临时路径,实际不会使用
    }
    
    // 使用项目中的 assets/datas 目录
    // Windows/Linux/macOS 需要返回包含 geosite 和 geoip 子目录的父目录
    
    // 开发环境：从项目根目录
    final devPathGeosite = path.join(Directory.current.path, 'assets', 'datas', 'geosite');
    final devPathGeoip = path.join(Directory.current.path, 'assets', 'datas', 'geoip');
    if (Directory(devPathGeosite).existsSync() && Directory(devPathGeoip).existsSync()) {
      return path.join(Directory.current.path, 'assets', 'datas');
    }

    // 发布环境：从 exe 同级目录
    final exeDir = path.dirname(Platform.resolvedExecutable);
    final bundlePathGeosite = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'datas', 'geosite');
    final bundlePathGeoip = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'datas', 'geoip');
    if (Directory(bundlePathGeosite).existsSync() && Directory(bundlePathGeoip).existsSync()) {
      return path.join(exeDir, 'data', 'flutter_assets', 'assets', 'datas');
    }

    // 备用：从当前目录
    return path.join(Directory.current.path, 'assets', 'datas');
  }

  /// 获取缓存数据库路径
  static String _getCacheDbPath() {
    String cachePath;
    
    if (Platform.isWindows) {
      final homeDir = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      final cacheDir = path.join(homeDir, '.vpn_client_demo');
      cachePath = path.join(cacheDir, 'cache.db');
      
      // 确保目录存在
      final dir = Directory(cacheDir);
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
          print('✅ 创建缓存目录: $cacheDir');
        } catch (e) {
          print('⚠️ 创建缓存目录失败: $e');
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      final cacheDir = path.join(homeDir, '.vpn_client_demo');
      cachePath = path.join(cacheDir, 'cache.db');
      
      // 确保目录存在
      final dir = Directory(cacheDir);
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
          print('✅ 创建缓存目录: $cacheDir');
        } catch (e) {
          print('⚠️ 创建缓存目录失败: $e');
        }
      }
    } else if (Platform.isAndroid) {
      // Android 使用应用内部存储
      // 使用 getApplicationDocumentsDirectory 或 getApplicationSupportDirectory
      // 简化实现: 禁用缓存文件
      cachePath = '';  // 空路径表示不使用缓存文件
    } else if (Platform.isIOS) {
      cachePath = '';  // iOS 也暂时不使用缓存
    } else {
      cachePath = './cache.db';
    }
    
    return cachePath;
  }
}

