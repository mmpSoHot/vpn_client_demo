import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class User {
  final String username;
  final String email;
  final bool isVip;
  final DateTime? vipExpireDate;

  User({
    required this.username,
    required this.email,
    this.isVip = false,
    this.vipExpireDate,
  });

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'isVip': isVip,
      'vipExpireDate': vipExpireDate?.toIso8601String(),
    };
  }

  // 从JSON创建User对象
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      email: json['email'],
      isVip: json['isVip'] ?? false,
      vipExpireDate: json['vipExpireDate'] != null 
          ? DateTime.parse(json['vipExpireDate'])
          : null,
    );
  }
}

class UserService extends ChangeNotifier {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  User? _currentUser;
  bool _isLoggedIn = false;
  SharedPreferences? _prefs;

  // 模拟用户数据库
  final Map<String, Map<String, dynamic>> _users = {
    'admin': {
      'password': '123456',
      'email': 'admin@example.com',
      'isVip': true,
      'vipExpireDate': DateTime.now().add(const Duration(days: 365)),
    },
    'user': {
      'password': '123456',
      'email': 'user@example.com',
      'isVip': false,
      'vipExpireDate': null,
    },
    'test': {
      'password': '123456',
      'email': 'test@example.com',
      'isVip': false,
      'vipExpireDate': null,
    },
  };

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  // 初始化SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadUserFromStorage();
  }

  // 从本地存储加载用户数据
  Future<void> _loadUserFromStorage() async {
    if (_prefs == null) return;

    final userJson = _prefs!.getString('current_user');
    if (userJson != null) {
      try {
        final userData = json.decode(userJson);
        _currentUser = User.fromJson(userData);
        _isLoggedIn = true;
        notifyListeners();
      } catch (e) {
        // 如果数据损坏，清除存储
        await _clearUserStorage();
      }
    }
  }

  // 保存用户数据到本地存储
  Future<void> _saveUserToStorage() async {
    if (_prefs == null) return;

    if (_currentUser != null) {
      final userJson = json.encode(_currentUser!.toJson());
      await _prefs!.setString('current_user', userJson);
      await _prefs!.setBool('is_logged_in', true);
    } else {
      await _clearUserStorage();
    }
  }

  // 清除本地存储的用户数据
  Future<void> _clearUserStorage() async {
    if (_prefs == null) return;

    await _prefs!.remove('current_user');
    await _prefs!.remove('is_logged_in');
  }

  // 模拟登录
  Future<Map<String, dynamic>> login(String username, String password) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 1000));

    if (_users.containsKey(username)) {
      final userData = _users[username]!;
      if (userData['password'] == password) {
        _currentUser = User(
          username: username,
          email: userData['email'],
          isVip: userData['isVip'],
          vipExpireDate: userData['vipExpireDate'],
        );
        _isLoggedIn = true;
        
        // 保存到本地存储
        await _saveUserToStorage();
        
        notifyListeners();
        
        return {
          'success': true,
          'message': '登录成功！',
          'user': _currentUser,
        };
      } else {
        return {
          'success': false,
          'message': '密码错误',
        };
      }
    } else {
      return {
        'success': false,
        'message': '用户不存在',
      };
    }
  }

  // 模拟注册
  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 1000));

    if (_users.containsKey(username)) {
      return {
        'success': false,
        'message': '用户名已存在',
      };
    }

    // 检查邮箱是否已存在
    for (var userData in _users.values) {
      if (userData['email'] == email) {
        return {
          'success': false,
          'message': '邮箱已被注册',
        };
      }
    }

    // 添加新用户
    _users[username] = {
      'password': password,
      'email': email,
      'isVip': false,
      'vipExpireDate': null,
    };

    return {
      'success': true,
      'message': '注册成功！',
    };
  }

  // 登出
  Future<void> logout() async {
    _currentUser = null;
    _isLoggedIn = false;
    
    // 清除本地存储
    await _clearUserStorage();
    
    notifyListeners();
  }

  // 更新用户VIP状态
  Future<void> updateVipStatus(bool isVip, {DateTime? expireDate}) async {
    if (_currentUser != null) {
      _currentUser = User(
        username: _currentUser!.username,
        email: _currentUser!.email,
        isVip: isVip,
        vipExpireDate: expireDate,
      );
      
      // 更新模拟数据库
      if (_users.containsKey(_currentUser!.username)) {
        _users[_currentUser!.username]!['isVip'] = isVip;
        _users[_currentUser!.username]!['vipExpireDate'] = expireDate;
      }
      
      // 保存到本地存储
      await _saveUserToStorage();
      
      notifyListeners();
    }
  }

  // 检查用户是否存在
  bool userExists(String username) {
    return _users.containsKey(username);
  }

  // 获取用户信息
  User? getUserInfo(String username) {
    if (_users.containsKey(username)) {
      final userData = _users[username]!;
      return User(
        username: username,
        email: userData['email'],
        isVip: userData['isVip'],
        vipExpireDate: userData['vipExpireDate'],
      );
    }
    return null;
  }

  // 检查是否记住密码
  Future<bool> isRememberPassword() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    return _prefs!.getBool('remember_password') ?? false;
  }

  // 设置记住密码
  Future<void> setRememberPassword(bool remember) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    await _prefs!.setBool('remember_password', remember);
  }

  // 保存登录凭据（如果记住密码）
  Future<void> saveCredentials(String username, String password) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    
    final remember = await isRememberPassword();
    if (remember) {
      await _prefs!.setString('saved_username', username);
      await _prefs!.setString('saved_password', password);
    } else {
      await _prefs!.remove('saved_username');
      await _prefs!.remove('saved_password');
    }
  }

  // 获取保存的登录凭据
  Future<Map<String, String?>> getSavedCredentials() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    
    final remember = await isRememberPassword();
    if (remember) {
      return {
        'username': _prefs!.getString('saved_username'),
        'password': _prefs!.getString('saved_password'),
      };
    }
    return {'username': null, 'password': null};
  }
} 