import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/node_model.dart';
import '../services/proxy_mode_service.dart';
import 'node_config_converter.dart';

/// Android VPN 辅助类
/// 通过 MethodChannel 与 Android VpnService 通信
class AndroidVpnHelper {
  static const MethodChannel _channel = MethodChannel('vpn_service');
  
  /// 检查 VPN 权限
  static Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod('checkPermission');
      return result == true;
    } catch (e) {
      print('检查 VPN 权限失败: $e');
      return false;
    }
  }
  
  /// 请求 VPN 权限
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod('requestPermission');
      return result == true;
    } catch (e) {
      print('请求 VPN 权限失败: $e');
      return false;
    }
  }
  
  /// 启动 VPN
  static Future<bool> startVpn({
    required NodeModel node,
    ProxyMode proxyMode = ProxyMode.bypassCN,
  }) async {
    if (!Platform.isAndroid) {
      print('⚠️ startVpn 仅支持 Android 平台');
      return false;
    }
    
    try {
      print('🚀 Android VPN 启动中...');
      print('   节点: ${node.displayName}');
      print('   模式: ${proxyMode == ProxyMode.bypassCN ? "绕过大陆" : "全局代理"}');
      
      // 生成 sing-box 配置（TUN 模式）
      final config = NodeConfigConverter.generateFullConfig(
        node: node,
        mixedPort: 15808,  // Android 可能不使用，但保留
        enableTun: true,   // Android 必须使用 TUN
        enableStatsApi: true,
        proxyMode: proxyMode,
      );
      
      // 将配置转换为 JSON 字符串
      final configJson = jsonEncode(config);
      
      // 调用 Android 端启动 VPN
      final result = await _channel.invokeMethod('startVpn', {
        'config': configJson,
      });
      
      if (result == true) {
        print('✅ Android VPN 启动成功');
        return true;
      } else {
        print('❌ Android VPN 启动失败');
        return false;
      }
    } catch (e) {
      print('❌ 启动 Android VPN 异常: $e');
      return false;
    }
  }
  
  /// 停止 VPN
  static Future<bool> stopVpn() async {
    if (!Platform.isAndroid) {
      print('⚠️ stopVpn 仅支持 Android 平台');
      return false;
    }
    
    try {
      print('🛑 停止 Android VPN...');
      
      final result = await _channel.invokeMethod('stopVpn');
      
      if (result == true) {
        print('✅ Android VPN 已停止');
        return true;
      } else {
        print('❌ Android VPN 停止失败');
        return false;
      }
    } catch (e) {
      print('❌ 停止 Android VPN 异常: $e');
      return false;
    }
  }
  
  /// 获取 VPN 状态
  static Future<bool> isRunning() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('isRunning');
      return result == true;
    } catch (e) {
      print('获取 VPN 状态失败: $e');
      return false;
    }
  }
}

