import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// HTTP客户端封装类
/// 提供统一的HTTP请求方法，包含token管理、错误处理等
class HttpClient {
  // 单例模式
  static final HttpClient _instance = HttpClient._internal();
  factory HttpClient() => _instance;
  HttpClient._internal();

  /// Token缓存
  String? _token;

  /// 获取Token
  Future<String?> getToken() async {
    if (_token != null) return _token;
    
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(ApiConfig.tokenKey);
    return _token;
  }

  /// 设置Token
  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(ApiConfig.tokenKey, token);
    } else {
      await prefs.remove(ApiConfig.tokenKey);
    }
  }

  /// 清除Token
  Future<void> clearToken() async {
    await setToken(null);
  }

  /// 构建请求头
  Future<Map<String, String>> _buildHeaders({Map<String, String>? extraHeaders}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // 添加Token
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      _log('Authorization: Bearer $token');
    } else {
      _log('No token found');
    }

    // 添加额外的请求头
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// 打印日志
  void _log(String message) {
    if (ApiConfig.enableLog) {
      print('[HttpClient] $message');
    }
  }

  /// 处理响应
  ApiResponse _handleResponse(http.Response response) {
    _log('Response Status: ${response.statusCode}');
    _log('Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final responseData = json.decode(response.body);
        
        // 检查响应格式：支持标准格式 {status, message, data, error}
        if (responseData is Map<String, dynamic>) {
          final status = responseData['status'];
          final message = responseData['message'];
          final data = responseData['data'];
          final error = responseData['error'];
          
          // 检查是否是登录失效的消息
          if (status == 'fail' && message != null && 
              (message.contains('未登录') || message.contains('登录已过期') || message.contains('登陆已过期'))) {
            // 清除token和用户状态
            clearToken();
            _clearUserSession();
            
            return ApiResponse(
              success: false,
              statusCode: 401,
              data: data,
              message: message,
              error: 'UNAUTHORIZED',
            );
          }
          
          // 判断业务是否成功
          if (status == 'success') {
            return ApiResponse(
              success: true,
              statusCode: response.statusCode,
              data: data,
              message: message,
            );
          } else {
            return ApiResponse(
              success: false,
              statusCode: response.statusCode,
              data: data,
              message: message ?? error ?? '请求失败',
            );
          }
        } else {
          // 兼容其他格式
          return ApiResponse(
            success: true,
            statusCode: response.statusCode,
            data: responseData,
          );
        }
      } catch (e) {
        return ApiResponse(
          success: false,
          statusCode: response.statusCode,
          message: '数据解析失败',
          error: e.toString(),
        );
      }
    } else if (response.statusCode == 401) {
      // Token过期或未授权
      clearToken();
      _clearUserSession();
      return ApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: '请先登录',
        error: 'UNAUTHORIZED',
      );
    } else {
      try {
        final data = json.decode(response.body);
        return ApiResponse(
          success: false,
          statusCode: response.statusCode,
          message: data['message'] ?? '请求失败',
          data: data,
        );
      } catch (e) {
        return ApiResponse(
          success: false,
          statusCode: response.statusCode,
          message: '请求失败',
        );
      }
    }
  }
  
  /// 清除用户会话
  void _clearUserSession() async {
    try {
      // 动态导入UserService避免循环依赖
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      await prefs.remove('is_logged_in');
      await prefs.remove('auth_data');
    } catch (e) {
      _log('Clear user session error: $e');
    }
  }

  /// GET请求
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.getFullUrl(path));
      final urlWithParams = params != null
          ? url.replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString())))
          : url;

      _log('GET Request: $urlWithParams');

      final requestHeaders = await _buildHeaders(extraHeaders: headers);
      final response = await http.get(urlWithParams, headers: requestHeaders)
          .timeout(Duration(milliseconds: ApiConfig.receiveTimeout));

      return _handleResponse(response);
    } catch (e) {
      _log('GET Error: $e');
      return ApiResponse(
        success: false,
        message: '网络请求失败',
        error: e.toString(),
      );
    }
  }

  /// POST请求
  Future<ApiResponse> post(
    String path, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.getFullUrl(path));
      _log('POST Request: $url');
      _log('POST Data: ${json.encode(data)}');

      final requestHeaders = await _buildHeaders(extraHeaders: headers);
      final response = await http.post(
        url,
        headers: requestHeaders,
        body: json.encode(data),
      ).timeout(Duration(milliseconds: ApiConfig.sendTimeout));

      return _handleResponse(response);
    } catch (e) {
      _log('POST Error: $e');
      return ApiResponse(
        success: false,
        message: '网络请求失败',
        error: e.toString(),
      );
    }
  }

  /// PUT请求
  Future<ApiResponse> put(
    String path, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.getFullUrl(path));
      _log('PUT Request: $url');
      _log('PUT Data: ${json.encode(data)}');

      final requestHeaders = await _buildHeaders(extraHeaders: headers);
      final response = await http.put(
        url,
        headers: requestHeaders,
        body: json.encode(data),
      ).timeout(Duration(milliseconds: ApiConfig.sendTimeout));

      return _handleResponse(response);
    } catch (e) {
      _log('PUT Error: $e');
      return ApiResponse(
        success: false,
        message: '网络请求失败',
        error: e.toString(),
      );
    }
  }

  /// DELETE请求
  Future<ApiResponse> delete(
    String path, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.getFullUrl(path));
      final urlWithParams = params != null
          ? url.replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString())))
          : url;

      _log('DELETE Request: $urlWithParams');

      final requestHeaders = await _buildHeaders(extraHeaders: headers);
      final response = await http.delete(urlWithParams, headers: requestHeaders)
          .timeout(Duration(milliseconds: ApiConfig.receiveTimeout));

      return _handleResponse(response);
    } catch (e) {
      _log('DELETE Error: $e');
      return ApiResponse(
        success: false,
        message: '网络请求失败',
        error: e.toString(),
      );
    }
  }
}

/// API响应封装类
class ApiResponse {
  /// 请求是否成功
  final bool success;

  /// HTTP状态码
  final int? statusCode;

  /// 响应数据
  final dynamic data;

  /// 错误消息
  final String? message;

  /// 错误详情
  final String? error;

  ApiResponse({
    required this.success,
    this.statusCode,
    this.data,
    this.message,
    this.error,
  });

  @override
  String toString() {
    return 'ApiResponse{success: $success, statusCode: $statusCode, message: $message}';
  }
}

