/// API配置类
/// 用于管理API网关地址、超时时间等配置
class ApiConfig {
  // 私有构造函数，防止实例化
  ApiConfig._();

  // ==================== 环境配置 ====================
  
  /// 当前环境（开发/测试/生产）
  static Environment currentEnvironment = Environment.development;

  /// 获取当前环境的API基础URL
  static String get baseUrl {
    switch (currentEnvironment) {
      case Environment.development:
        return devBaseUrl;
      case Environment.staging:
        return stagingBaseUrl;
      case Environment.production:
        return prodBaseUrl;
    }
  }

  // ==================== API网关地址 ====================
  
  /// 开发环境API地址
  static String devBaseUrl = 'http://127.0.0.1:8004/api/v1';
  
  /// 测试环境API地址
  static String stagingBaseUrl = 'http://127.0.0.1:8004/api/v1';
  
  /// 生产环境API地址
  static String prodBaseUrl = 'http://127.0.0.1:8004/api/v1';

  // ==================== 超时配置 ====================
  
  /// 连接超时时间（毫秒）
  static const int connectTimeout = 15000;
  
  /// 接收超时时间（毫秒）
  static const int receiveTimeout = 15000;
  
  /// 发送超时时间（毫秒）
  static const int sendTimeout = 15000;

  // ==================== API路径 ====================
  
  /// 用户相关接口
  static const String loginPath = '/passport/auth/login';
  static const String registerPath = '/passport/auth/register';
  static const String logoutPath = '/user/logout';
  static const String userInfoPath = '/user/info';
  static const String updateUserPath = '/user/update';
  static const String sendEmailVerifyPath = '/passport/comm/sendEmailVerify';
  static const String getSubscribePath = '/user/getSubscribe';
  
  /// VIP相关接口
  static const String vipInfoPath = '/vip/info';
  static const String vipRechargePath = '/vip/recharge';
  static const String vipOrdersPath = '/vip/orders';
  static const String planFetchPath = '/user/plan/fetch';
  
  /// 节点相关接口
  static const String nodeListPath = '/node/list';
  static const String nodeSelectPath = '/node/select';
  static const String nodePingPath = '/node/ping';
  
  /// 代理相关接口
  static const String proxyConnectPath = '/proxy/connect';
  static const String proxyDisconnectPath = '/proxy/disconnect';
  static const String proxyStatusPath = '/proxy/status';
  static const String proxyModeSelectPath = '/proxy/mode/select';
  
  /// 统计相关接口
  static const String statisticsPath = '/statistics/usage';
  static const String statisticsDetailPath = '/statistics/detail';
  static const String trafficLogPath = '/user/stat/getTrafficLog';
  
  /// 全局配置接口
  static const String guestConfigPath = '/guest/comm/config';

  // ==================== 其他配置 ====================
  
  /// 是否启用日志
  static bool enableLog = true;
  
  /// 是否启用HTTPS证书验证
  static bool enableCertificateVerification = true;
  
  /// Token存储键名
  static const String tokenKey = 'auth_token';
  
  /// 用户信息存储键名
  static const String userInfoKey = 'user_info';

  // ==================== 工具方法 ====================
  
  /// 获取完整的API URL
  static String getFullUrl(String path) {
    return '$baseUrl$path';
  }
  
  /// 切换环境
  static void setEnvironment(Environment env) {
    currentEnvironment = env;
  }
  
  /// 设置自定义基础URL（用于动态配置）
  static void setCustomBaseUrl(String url) {
    switch (currentEnvironment) {
      case Environment.development:
        devBaseUrl = url;
        break;
      case Environment.staging:
        stagingBaseUrl = url;
        break;
      case Environment.production:
        prodBaseUrl = url;
        break;
    }
  }
}

/// 环境枚举
enum Environment {
  /// 开发环境
  development,
  
  /// 测试环境
  staging,
  
  /// 生产环境
  production,
}

