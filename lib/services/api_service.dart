import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/http_client.dart';

/// API服务层
/// 封装所有后端API接口调用
class ApiService {
  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final HttpClient _httpClient = HttpClient();

  // ==================== 用户相关接口 ====================

  /// 用户登录
  /// [email] 邮箱
  /// [password] 密码
  Future<ApiResponse> login(String email, String password) async {
    final response = await _httpClient.post(
      ApiConfig.loginPath,
      data: {
        'email': email,
        'password': password,
      },
    );
    
    // 如果登录成功，保存token
    if (response.success && response.data != null) {
      final authData = response.data['auth_data']; // 格式: "Bearer xxx"
      
      print('=== 登录成功，保存Token ===');
      print('auth_data: $authData');
      
      // auth_data已经包含Bearer前缀，提取token
      if (authData != null && authData.toString().startsWith('Bearer ')) {
        // 提取Bearer后面的token部分
        final token = authData.toString().substring(7); // 去掉"Bearer "
        print('提取的token: $token');
        
        await _httpClient.setToken(token);
        print('Token已保存到HttpClient');
        
        // 同时保存完整的auth_data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_data', authData);
        print('auth_data已保存到本地');
      } else {
        print('⚠️ auth_data格式不正确或为空');
      }
      print('=== Token保存完成 ===');
    }
    
    return response;
  }

  /// 用户注册
  /// [email] 邮箱
  /// [password] 密码
  /// [emailCode] 邮箱验证码（可选）
  /// [inviteCode] 邀请码（可选）
  Future<ApiResponse> register({
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  }) async {
    final data = {
      'email': email,
      'password': password,
    };
    
    // 添加可选参数
    if (emailCode != null && emailCode.isNotEmpty) {
      data['email_code'] = emailCode;
    }
    
    if (inviteCode != null && inviteCode.isNotEmpty) {
      data['invite_code'] = inviteCode;
    }
    
    return await _httpClient.post(
      ApiConfig.registerPath,
      data: data,
    );
  }

  /// 登出
  Future<ApiResponse> logout() async {
    return await _httpClient.post(ApiConfig.logoutPath);
  }

  /// 获取用户信息
  Future<ApiResponse> getUserInfo() async {
    return await _httpClient.get(ApiConfig.userInfoPath);
  }

  /// 获取用户订阅信息
  Future<ApiResponse> getSubscribe() async {
    return await _httpClient.get(ApiConfig.getSubscribePath);
  }

  /// 更新用户信息
  /// [data] 更新的用户数据
  Future<ApiResponse> updateUser(Map<String, dynamic> data) async {
    return await _httpClient.put(
      ApiConfig.updateUserPath,
      data: data,
    );
  }

  // ==================== VIP相关接口 ====================

  /// 获取套餐列表
  Future<ApiResponse> fetchPlans() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return await _httpClient.get(
      ApiConfig.planFetchPath,
      params: {
        't': timestamp,
      },
    );
  }

  /// 根据ID获取套餐详情
  Future<ApiResponse> fetchPlanById(int id) async {
    return await _httpClient.get(
      ApiConfig.planFetchPath,
      params: { 'id': id },
    );
  }

  /// 获取VIP信息
  Future<ApiResponse> getVipInfo() async {
    return await _httpClient.get(ApiConfig.vipInfoPath);
  }

  /// VIP充值
  /// [planId] 套餐ID
  /// [paymentMethod] 支付方式
  Future<ApiResponse> vipRecharge(String planId, String paymentMethod) async {
    return await _httpClient.post(
      ApiConfig.vipRechargePath,
      data: {
        'plan_id': planId,
        'payment_method': paymentMethod,
      },
    );
  }

  /// 获取VIP订单列表
  /// [page] 页码
  /// [pageSize] 每页数量
  Future<ApiResponse> getVipOrders({int page = 1, int pageSize = 10}) async {
    return await _httpClient.get(
      ApiConfig.vipOrdersPath,
      params: {
        'page': page,
        'page_size': pageSize,
      },
    );
  }

  /// 拉取用户订单（用于检查未支付订单）
  Future<ApiResponse> fetchOrders() async {
    return await _httpClient.get(ApiConfig.orderFetchPath);
  }

  /// 取消订单（按交易号）
  Future<ApiResponse> cancelOrderByTradeNo(String tradeNo) async {
    return await _httpClient.post(
      ApiConfig.orderCancelPath,
      data: {
        'trade_no': tradeNo,
      },
    );
  }

  /// 创建订单
  /// [planId] 套餐ID
  /// [periodKey] 购买周期键（month_price|quarter_price|half_year_price|year_price）
  Future<ApiResponse> createOrder({required int planId, required String periodKey}) async {
    return await _httpClient.post(
      ApiConfig.orderSavePath,
      data: {
        'plan_id': planId,
        'period': periodKey,
      },
    );
  }

  /// 验证优惠券
  Future<ApiResponse> checkCoupon({required int planId, required String code}) async {
    return await _httpClient.post(
      ApiConfig.couponCheckPath,
      data: {
        'plan_id': planId,
        'code': code,
      },
    );
  }

  // ==================== 节点相关接口 ====================

  /// 获取节点列表
  Future<ApiResponse> getNodeList() async {
    return await _httpClient.get(ApiConfig.nodeListPath);
  }

  /// 选择节点
  /// [nodeId] 节点ID
  Future<ApiResponse> selectNode(String nodeId) async {
    return await _httpClient.post(
      ApiConfig.nodeSelectPath,
      data: {
        'node_id': nodeId,
      },
    );
  }

  /// 测试节点延迟
  /// [nodeId] 节点ID
  Future<ApiResponse> pingNode(String nodeId) async {
    return await _httpClient.post(
      ApiConfig.nodePingPath,
      data: {
        'node_id': nodeId,
      },
    );
  }

  // ==================== 代理相关接口 ====================

  /// 连接代理
  /// [nodeId] 节点ID
  /// [mode] 代理模式
  Future<ApiResponse> connectProxy(String nodeId, String mode) async {
    return await _httpClient.post(
      ApiConfig.proxyConnectPath,
      data: {
        'node_id': nodeId,
        'mode': mode,
      },
    );
  }

  /// 断开代理
  Future<ApiResponse> disconnectProxy() async {
    return await _httpClient.post(ApiConfig.proxyDisconnectPath);
  }

  /// 获取代理状态
  Future<ApiResponse> getProxyStatus() async {
    return await _httpClient.get(ApiConfig.proxyStatusPath);
  }

  /// 选择代理模式
  /// [mode] 代理模式（全局/规则/直连）
  Future<ApiResponse> selectProxyMode(String mode) async {
    return await _httpClient.post(
      ApiConfig.proxyModeSelectPath,
      data: {
        'mode': mode,
      },
    );
  }

  // ==================== 统计相关接口 ====================

  /// 获取流量记录日志
  Future<ApiResponse> getTrafficLog() async {
    return await _httpClient.get(ApiConfig.trafficLogPath);
  }

  /// 获取使用统计列表
  /// [page] 页码
  /// [pageSize] 每页数量
  Future<ApiResponse> getStatistics({int page = 1, int pageSize = 10}) async {
    return await _httpClient.get(
      ApiConfig.statisticsPath,
      params: {
        'page': page,
        'page_size': pageSize,
      },
    );
  }

  /// 获取统计详情
  /// [date] 日期 (格式: YYYY-MM-DD)
  Future<ApiResponse> getStatisticsDetail(String date) async {
    return await _httpClient.get(
      ApiConfig.statisticsDetailPath,
      params: {
        'date': date,
      },
    );
  }

  // ==================== 配置相关接口 ====================

  /// 获取全局配置
  Future<ApiResponse> getGuestConfig() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return await _httpClient.get(
      ApiConfig.guestConfigPath,
      params: {
        't': timestamp,
      },
    );
  }

  /// 发送邮箱验证码
  /// [email] 邮箱地址
  Future<ApiResponse> sendEmailVerify(String email) async {
    return await _httpClient.post(
      ApiConfig.sendEmailVerifyPath,
      data: {
        'email': email,
      },
    );
  }

  // ==================== 订阅相关接口 ====================

  /// 获取订阅节点数据（Base64编码）
  /// [subscribeUrl] 订阅链接
  Future<String> getSubscriptionNodes(String subscribeUrl) async {
    try {
      final response = await _httpClient.getRaw(subscribeUrl);
      return response;
    } catch (e) {
      print('获取订阅节点失败: $e');
      return '';
    }
  }
}

