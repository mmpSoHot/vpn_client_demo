import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket 网速监控服务（参考 karing 实现）
class WebSocketSpeedService {
  static const String _wsBaseUrl = 'ws://127.0.0.1:9090';
  static const Duration _reconnectInterval = Duration(seconds: 5);
  
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  
  // 实时速度通知器
  final ValueNotifier<String> uploadSpeedNotifier = ValueNotifier("0 B/s");
  final ValueNotifier<String> downloadSpeedNotifier = ValueNotifier("0 B/s");
  
  // 单例模式
  static final WebSocketSpeedService _instance = WebSocketSpeedService._internal();
  factory WebSocketSpeedService() => _instance;
  WebSocketSpeedService._internal();
  
  /// 开始监控网速
  void startMonitoring() {
    if (_isConnected) return;
    
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    print('🚀 开始 WebSocket 网速监控...');
    _connect();
  }
  
  /// 停止监控网速
  void stopMonitoring() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _disconnect();
    
    // 重置显示
    uploadSpeedNotifier.value = "0 B/s";
    downloadSpeedNotifier.value = "0 B/s";
    
    print('⏹️ 停止 WebSocket 网速监控');
  }
  
  /// 连接到 WebSocket
  void _connect() {
    try {
      // Clash API 的 /traffic 端点使用 WebSocket 推送实时流量数据
      final wsUrl = '$_wsBaseUrl/traffic';
      
      if (_reconnectAttempts == 0) {
        print('🔗 连接到 WebSocket: $wsUrl');
      }
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
      
      _isConnected = true;
      _reconnectAttempts = 0; // 重置重连次数
      print('✅ WebSocket 连接成功');
    } catch (e) {
      if (_reconnectAttempts < _maxReconnectAttempts) {
        if (kDebugMode) {
          print('❌ WebSocket 连接失败 (尝试 ${_reconnectAttempts + 1}/$_maxReconnectAttempts): $e');
        }
        _reconnectAttempts++;
        _scheduleReconnect();
      } else {
        if (kDebugMode) {
          print('⚠️ WebSocket 连接失败次数过多，停止重连。请检查 sing-box 是否正确启动了 Clash API。');
        }
        _shouldReconnect = false;
      }
    }
  }
  
  /// 断开 WebSocket 连接
  void _disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }
  
  /// 处理接收到的消息
  void _onMessage(dynamic message) {
    try {
      if (message is String) {
        final data = json.decode(message);
        _processConnectionsData(data);
      }
    } catch (e) {
      print('⚠️ 处理 WebSocket 消息失败: $e');
    }
  }
  
  /// 处理流量数据
  void _processConnectionsData(Map<String, dynamic> data) {
    try {
      // Clash API /traffic 端点返回格式: {"up": 12345, "down": 67890}
      final uploadSpeed = data['up'] ?? 0;
      final downloadSpeed = data['down'] ?? 0;
      
      // 确保数据是数字类型
      final upload = _toInt(uploadSpeed);
      final download = _toInt(downloadSpeed);
      
      uploadSpeedNotifier.value = _formatSpeed(upload);
      downloadSpeedNotifier.value = _formatSpeed(download);
      
      if (kDebugMode && (upload > 0 || download > 0)) {
        print('📊 网速更新: ↑${_formatSpeed(upload)} ↓${_formatSpeed(download)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 解析流量数据失败: $e');
        print('数据内容: $data');
      }
    }
  }
  
  /// 转换为整数
  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  /// 格式化速度显示
  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }
  
  /// WebSocket 错误处理
  void _onError(error) {
    _isConnected = false;
    if (_reconnectAttempts < _maxReconnectAttempts) {
      if (kDebugMode) {
        print('❌ WebSocket 错误 (尝试 ${_reconnectAttempts + 1}/$_maxReconnectAttempts): $error');
      }
      _reconnectAttempts++;
      _scheduleReconnect();
    } else {
      if (kDebugMode) {
        print('⚠️ WebSocket 错误次数过多，停止重连');
      }
      _shouldReconnect = false;
    }
  }
  
  /// WebSocket 连接关闭
  void _onDone() {
    _isConnected = false;
    if (_shouldReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      if (kDebugMode) {
        print('🔌 WebSocket 连接已关闭，准备重连...');
      }
      _scheduleReconnect();
    } else if (kDebugMode && _reconnectAttempts >= _maxReconnectAttempts) {
      print('⚠️ 已达到最大重连次数，停止重连');
    }
  }
  
  /// 安排重连
  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectAttempts >= _maxReconnectAttempts) return;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectInterval, () {
      if (_shouldReconnect && !_isConnected && _reconnectAttempts < _maxReconnectAttempts) {
        if (kDebugMode) {
          print('🔄 尝试重新连接 WebSocket (${_reconnectAttempts + 1}/$_maxReconnectAttempts)...');
        }
        _connect();
      }
    });
  }
  
  /// 检查连接状态
  bool get isConnected => _isConnected;
  
  /// 获取当前速度（用于测试）
  Map<String, String> getCurrentSpeed() {
    return {
      'upload': uploadSpeedNotifier.value,
      'download': downloadSpeedNotifier.value,
    };
  }
  
  /// 销毁服务
  void dispose() {
    stopMonitoring();
    uploadSpeedNotifier.dispose();
    downloadSpeedNotifier.dispose();
  }
}
