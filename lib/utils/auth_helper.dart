import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../pages/login_page.dart';
import 'http_client.dart';

/// 认证辅助类
/// 用于处理登录失效等认证相关问题
class AuthHelper {
  /// 检查API响应是否为未授权
  static bool isUnauthorized(ApiResponse response) {
    return response.statusCode == 401 || response.error == 'UNAUTHORIZED';
  }

  /// 处理未授权情况
  /// 清除登录状态并跳转到登录页面
  static Future<void> handleUnauthorized(BuildContext context, {String? message}) async {
    final userService = UserService();
    
    // 清除用户登录状态
    await userService.logout();
    
    if (context.mounted) {
      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? '登录已过期，请重新登录'),
          backgroundColor: const Color(0xFFF44336),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // 延迟一下再跳转
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 跳转到登录页面，清除所有路由栈
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  /// 在页面中使用的便捷方法
  /// 检查响应并自动处理未授权情况
  static Future<bool> checkAndHandleAuth(BuildContext context, ApiResponse response) async {
    if (isUnauthorized(response)) {
      await handleUnauthorized(context, message: response.message);
      return false; // 返回false表示未授权
    }
    return true; // 返回true表示已授权
  }
}

