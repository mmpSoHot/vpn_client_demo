import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/http_client.dart';

/// 全局配置服务
/// 在应用启动时获取配置并存储到本地
class ConfigService {
  // 单例模式
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final HttpClient _httpClient = HttpClient();
  SharedPreferences? _prefs;
  AppConfig? _config;

  /// 配置是否已加载
  bool get isLoaded => _config != null;

  /// 获取当前配置
  AppConfig? get config => _config;

  /// 初始化配置服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // 先从本地加载配置
    await _loadFromLocal();
    
    // 然后从服务器获取最新配置
    await fetchConfig();
  }

  /// 从服务器获取配置
  Future<bool> fetchConfig() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _httpClient.get(
        ApiConfig.guestConfigPath,
        params: {'t': timestamp},
      );

      if (response.success && response.data != null) {
        _config = AppConfig.fromJson(response.data);
        await _saveToLocal(response.data);
        print('✅ 全局配置加载成功');
        return true;
      } else {
        print('⚠️ 全局配置加载失败: ${response.message}');
        return false;
      }
    } catch (e) {
      print('❌ 全局配置加载异常: $e');
      return false;
    }
  }

  /// 保存配置到本地
  Future<void> _saveToLocal(Map<String, dynamic> configData) async {
    if (_prefs == null) return;
    
    final configJson = json.encode(configData);
    await _prefs!.setString('app_config', configJson);
    await _prefs!.setInt('config_update_time', DateTime.now().millisecondsSinceEpoch);
  }

  /// 从本地加载配置
  Future<void> _loadFromLocal() async {
    if (_prefs == null) return;
    
    final configJson = _prefs!.getString('app_config');
    if (configJson != null) {
      try {
        final configData = json.decode(configJson);
        _config = AppConfig.fromJson(configData);
        print('📦 从本地加载配置成功');
      } catch (e) {
        print('❌ 本地配置解析失败: $e');
      }
    }
  }

  /// 清除本地配置
  Future<void> clearConfig() async {
    if (_prefs == null) return;
    
    await _prefs!.remove('app_config');
    await _prefs!.remove('config_update_time');
    _config = null;
  }

  /// 获取配置更新时间
  DateTime? getConfigUpdateTime() {
    if (_prefs == null) return null;
    
    final timestamp = _prefs!.getInt('config_update_time');
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  // ==================== 便捷访问方法 ====================

  /// 是否开启邮箱验证
  bool get isEmailVerify => _config?.isEmailVerify ?? false;

  /// 注册是否强制邀请
  bool get isInviteForce => _config?.isInviteForce ?? false;

  /// 邮箱白名单后缀
  List<String> get emailWhitelistSuffix => _config?.emailWhitelistSuffix ?? [];

  /// 是否启用验证码
  bool get isCaptcha => _config?.isCaptcha ?? false;

  /// 验证码类型
  String? get captchaType => _config?.captchaType;

  /// App描述
  String get appDescription => _config?.appDescription ?? '代理工具';

  /// App URL
  String? get appUrl => _config?.appUrl;

  /// Logo URL
  String? get logo => _config?.logo;

  /// TOS URL
  String? get tosUrl => _config?.tosUrl;

  /// 检查邮箱后缀是否在白名单中
  bool isEmailSuffixAllowed(String email) {
    if (emailWhitelistSuffix.isEmpty) return true;
    
    final suffix = email.split('@').last.toLowerCase();
    return emailWhitelistSuffix.any((allowed) => allowed.toLowerCase() == suffix);
  }

  /// 获取邮箱后缀选项（用于下拉选择）
  List<String> getEmailSuffixOptions() {
    return emailWhitelistSuffix.isNotEmpty 
        ? emailWhitelistSuffix 
        : ['gmail.com', 'qq.com', '163.com', 'outlook.com'];
  }
}

/// 应用配置数据模型
class AppConfig {
  final String? tosUrl;
  final bool isEmailVerify;
  final bool isInviteForce;
  final List<String> emailWhitelistSuffix;
  final bool isCaptcha;
  final String? captchaType;
  final String? recaptchaSiteKey;
  final String? recaptchaV3SiteKey;
  final double? recaptchaV3ScoreThreshold;
  final String? turnstileSiteKey;
  final String appDescription;
  final String? appUrl;
  final String? logo;
  final bool isRecaptcha;

  AppConfig({
    this.tosUrl,
    required this.isEmailVerify,
    required this.isInviteForce,
    required this.emailWhitelistSuffix,
    required this.isCaptcha,
    this.captchaType,
    this.recaptchaSiteKey,
    this.recaptchaV3SiteKey,
    this.recaptchaV3ScoreThreshold,
    this.turnstileSiteKey,
    required this.appDescription,
    this.appUrl,
    this.logo,
    required this.isRecaptcha,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      tosUrl: json['tos_url'],
      isEmailVerify: (json['is_email_verify'] ?? 0) == 1,
      isInviteForce: (json['is_invite_force'] ?? 0) == 1,
      emailWhitelistSuffix: json['email_whitelist_suffix'] != null
          ? List<String>.from(json['email_whitelist_suffix'])
          : [],
      isCaptcha: (json['is_captcha'] ?? 0) == 1,
      captchaType: json['captcha_type'],
      recaptchaSiteKey: json['recaptcha_site_key'],
      recaptchaV3SiteKey: json['recaptcha_v3_site_key'],
      recaptchaV3ScoreThreshold: json['recaptcha_v3_score_threshold']?.toDouble(),
      turnstileSiteKey: json['turnstile_site_key'],
      appDescription: json['app_description'] ?? '代理工具',
      appUrl: json['app_url'],
      logo: json['logo'],
      isRecaptcha: (json['is_recaptcha'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tos_url': tosUrl,
      'is_email_verify': isEmailVerify ? 1 : 0,
      'is_invite_force': isInviteForce ? 1 : 0,
      'email_whitelist_suffix': emailWhitelistSuffix,
      'is_captcha': isCaptcha ? 1 : 0,
      'captcha_type': captchaType,
      'recaptcha_site_key': recaptchaSiteKey,
      'recaptcha_v3_site_key': recaptchaV3SiteKey,
      'recaptcha_v3_score_threshold': recaptchaV3ScoreThreshold,
      'turnstile_site_key': turnstileSiteKey,
      'app_description': appDescription,
      'app_url': appUrl,
      'logo': logo,
      'is_recaptcha': isRecaptcha ? 1 : 0,
    };
  }
}

