# 配置服务使用说明

## 功能概述

`ConfigService` 在应用启动时自动获取服务端全局配置并保存到本地，提供便捷的访问方法。

## 配置内容

### 1. 邮箱验证相关
- `isEmailVerify`: 是否开启邮箱验证
- `emailWhitelistSuffix`: 邮箱注册白名单后缀列表
  - 例如: `['gmail.com', 'qq.com', '163.com', 'yahoo.com']`
  - 只有这些后缀的邮箱才能注册

### 2. 注册相关
- `isInviteForce`: 注册是否强制需要邀请码
- `isCaptcha`: 是否启用验证码
- `captchaType`: 验证码类型 (recaptcha/turnstile)

### 3. 应用信息
- `appDescription`: App描述
- `logo`: Logo URL
- `appUrl`: 官网地址
- `tosUrl`: 服务条款URL

## 使用方法

### 1. 获取配置服务实例

```dart
import 'package:demo2/services/config_service.dart';

final configService = ConfigService();
```

### 2. 访问配置项

```dart
// 检查是否开启邮箱验证
if (configService.isEmailVerify) {
  print('需要邮箱验证');
}

// 检查是否强制邀请
if (configService.isInviteForce) {
  print('注册需要邀请码');
}

// 获取App描述
String description = configService.appDescription;
print('App描述: $description');

// 获取Logo
String? logo = configService.logo;
if (logo != null) {
  print('Logo URL: $logo');
}
```

### 3. 邮箱后缀验证

```dart
// 检查邮箱后缀是否在白名单中
String email = 'user@gmail.com';
if (configService.isEmailSuffixAllowed(email)) {
  print('邮箱后缀允许注册');
} else {
  print('邮箱后缀不在白名单中');
}

// 获取所有允许的邮箱后缀（用于下拉选择）
List<String> suffixes = configService.getEmailSuffixOptions();
// 结果: ['gmail.com', 'qq.com', '163.com', 'yahoo.com', ...]
```

### 4. 在注册页面中使用

```dart
class RegisterPage extends StatefulWidget {
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final ConfigService _configService = ConfigService();
  String _selectedSuffix = 'gmail.com';
  
  @override
  void initState() {
    super.initState();
    // 设置默认后缀为第一个
    final suffixes = _configService.getEmailSuffixOptions();
    if (suffixes.isNotEmpty) {
      _selectedSuffix = suffixes.first;
    }
  }
  
  Widget _buildEmailInput() {
    final suffixes = _configService.getEmailSuffixOptions();
    
    return Row(
      children: [
        // 邮箱用户名输入框
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: '邮箱用户名',
            ),
          ),
        ),
        Text('@'),
        // 邮箱后缀下拉选择
        DropdownButton<String>(
          value: _selectedSuffix,
          items: suffixes.map((suffix) {
            return DropdownMenuItem(
              value: suffix,
              child: Text(suffix),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSuffix = value!;
            });
          },
        ),
      ],
    );
  }
  
  void _register() {
    // 检查是否需要邀请码
    if (_configService.isInviteForce) {
      // 显示邀请码输入框
    }
    
    // 检查是否需要邮箱验证
    if (_configService.isEmailVerify) {
      // 发送验证码
    }
    
    // 构建完整邮箱
    String email = '$usernameInput@$_selectedSuffix';
    
    // 验证邮箱后缀
    if (!_configService.isEmailSuffixAllowed(email)) {
      // 显示错误提示
      return;
    }
    
    // 继续注册流程...
  }
}
```

### 5. 手动刷新配置

```dart
// 从服务器重新获取配置
bool success = await configService.fetchConfig();
if (success) {
  print('配置更新成功');
} else {
  print('配置更新失败');
}
```

### 6. 检查配置状态

```dart
// 检查配置是否已加载
if (configService.isLoaded) {
  print('配置已加载');
}

// 获取配置更新时间
DateTime? updateTime = configService.getConfigUpdateTime();
if (updateTime != null) {
  print('配置最后更新时间: $updateTime');
}
```

### 7. 清除配置

```dart
// 清除本地保存的配置
await configService.clearConfig();
```

## 配置数据结构

```dart
class AppConfig {
  String? tosUrl;                    // 服务条款URL
  bool isEmailVerify;                // 是否开启邮箱验证
  bool isInviteForce;                // 是否强制邀请
  List<String> emailWhitelistSuffix; // 邮箱白名单后缀
  bool isCaptcha;                    // 是否启用验证码
  String? captchaType;               // 验证码类型
  String appDescription;             // App描述
  String? appUrl;                    // 官网URL
  String? logo;                      // Logo URL
  bool isRecaptcha;                  // 是否使用reCAPTCHA
}
```

## 注意事项

1. **自动初始化**: 配置服务在应用启动时(main.dart)自动初始化，无需手动调用
2. **本地缓存**: 配置会保存到本地，即使离线也能访问
3. **自动更新**: 每次应用启动都会尝试从服务器获取最新配置
4. **单例模式**: 全局只有一个实例，任何地方获取的都是同一个对象
5. **线程安全**: 使用SharedPreferences保证数据持久化

## 完整示例：注册表单验证

```dart
void validateRegistration(String username, String suffix, String? inviteCode) {
  final configService = ConfigService();
  
  // 1. 构建完整邮箱
  String email = '$username@$suffix';
  
  // 2. 验证邮箱后缀
  if (!configService.isEmailSuffixAllowed(email)) {
    showError('该邮箱后缀不支持注册');
    return;
  }
  
  // 3. 检查是否需要邀请码
  if (configService.isInviteForce && (inviteCode == null || inviteCode.isEmpty)) {
    showError('请输入邀请码');
    return;
  }
  
  // 4. 检查是否需要邮箱验证
  if (configService.isEmailVerify) {
    // 发送验证码到邮箱
    sendVerificationCode(email);
  } else {
    // 直接注册
    register(email);
  }
}
```

