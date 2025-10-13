# 登录功能测试步骤

## 问题诊断

登录成功后个人中心显示未登录，可能的原因：

1. ✅ UserService单例正常
2. ✅ ProfilePage已设置监听器
3. ✅ `setUserFromApi`方法已调用`notifyListeners()`
4. ⚠️ 需要检查：登录后是否正确保存了用户数据

## 测试步骤

### 1. 测试登录API
```dart
// 在登录页面，输入以下信息：
Email: 949684777@qq.com
Password: 168168wwWW
```

### 2. 检查日志输出

登录成功后，应该看到以下日志（如果enableLog=true）：
```
[HttpClient] POST Request: https://1.kscspeed.online/api/v1/passport/auth/login
[HttpClient] POST Data: {"email":"949684777@qq.com","password":"..."}
[HttpClient] Response Status: 200
[HttpClient] Response Body: {"status":"success",...}
```

### 3. 检查保存的数据

添加调试代码到`setUserFromApi`方法：
```dart
Future<void> setUserFromApi(String email, {bool isVip = false, bool isAdmin = false}) async {
  final username = email.split('@')[0];
  
  _currentUser = User(
    username: username,
    email: email,
    isVip: isVip,
    vipExpireDate: isVip ? DateTime.now().add(const Duration(days: 365)) : null,
  );
  _isLoggedIn = true;
  
  print('=== UserService.setUserFromApi ===');
  print('Email: $email');
  print('Username: $username');
  print('IsVip: $isVip');
  print('IsAdmin: $isAdmin');
  print('_isLoggedIn: $_isLoggedIn');
  print('_currentUser: $_currentUser');
  
  await _saveUserToStorage();
  
  print('User saved to storage');
  
  notifyListeners();
  
  print('Listeners notified');
  print('=== End ===');
}
```

### 4. 验证ProfilePage接收到通知

在ProfilePage的`_onUserServiceChanged`方法中添加日志：
```dart
void _onUserServiceChanged() {
  print('=== ProfilePage._onUserServiceChanged ===');
  print('UserService.isLoggedIn: ${_userService.isLoggedIn}');
  print('UserService.currentUser: ${_userService.currentUser}');
  _loadUserInfo();
  print('Local _isLoggedIn: $_isLoggedIn');
  print('Local _currentUser: $_currentUser');
  print('=== End ===');
}
```

## 可能的解决方案

如果问题仍然存在，可能需要：

1. **强制刷新ProfilePage**
   登录成功后，主动调用ProfilePage的刷新方法

2. **延迟跳转**
   在`notifyListeners()`之后稍微延迟再跳转页面
   ```dart
   await _userService.setUserFromApi(...);
   await Future.delayed(Duration(milliseconds: 100));
   Navigator.pushReplacement(...);
   ```

3. **检查SharedPreferences初始化**
   确保UserService的`_prefs`已经初始化

4. **使用全局状态管理**
   考虑使用Provider等状态管理方案

