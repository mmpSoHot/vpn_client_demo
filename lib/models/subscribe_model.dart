/// 用户订阅数据模型
class SubscribeModel {
  final int? planId;
  final String token;
  final int expiredAt;
  final int u;                    // 已用上行（字节）
  final int d;                    // 已用下行（字节）
  final int transferEnable;       // 总流量（字节）
  final String email;
  final String uuid;
  final int? deviceLimit;
  final int? speedLimit;
  final int? nextResetAt;
  final String subscribeUrl;
  final int? resetDay;
  final PlanInfo? plan;

  SubscribeModel({
    this.planId,
    required this.token,
    required this.expiredAt,
    required this.u,
    required this.d,
    required this.transferEnable,
    required this.email,
    required this.uuid,
    this.deviceLimit,
    this.speedLimit,
    this.nextResetAt,
    required this.subscribeUrl,
    this.resetDay,
    this.plan,
  });

  factory SubscribeModel.fromJson(Map<String, dynamic> json) {
    return SubscribeModel(
      planId: json['plan_id'],
      token: json['token'] ?? '',
      expiredAt: json['expired_at'] ?? 0,
      u: json['u'] ?? 0,
      d: json['d'] ?? 0,
      transferEnable: json['transfer_enable'] ?? 0,
      email: json['email'] ?? '',
      uuid: json['uuid'] ?? '',
      deviceLimit: json['device_limit'],
      speedLimit: json['speed_limit'],
      nextResetAt: json['next_reset_at'],
      subscribeUrl: json['subscribe_url'] ?? '',
      resetDay: json['reset_day'],
      plan: json['plan'] != null ? PlanInfo.fromJson(json['plan']) : null,
    );
  }

  /// 是否已购买订阅
  bool get hasSubscription => planId != null && plan != null;

  /// 获取订阅名称
  String get planName => plan?.name ?? '未订阅';

  /// 计算已用流量（字节）
  int get usedTraffic => u + d;

  /// 获取已用流量（格式化）
  String get usedTrafficFormatted => _formatBytes(usedTraffic);

  /// 获取总流量（格式化）
  String get totalTrafficFormatted => _formatBytes(transferEnable);

  /// 计算流量使用百分比（0-100）
  double get usagePercentage {
    if (transferEnable == 0) return 0;
    return (usedTraffic / transferEnable * 100).clamp(0, 100);
  }

  /// 获取剩余流量（字节）
  int get remainingTraffic => (transferEnable - usedTraffic).clamp(0, transferEnable);

  /// 获取剩余流量（格式化）
  String get remainingTrafficFormatted => _formatBytes(remainingTraffic);

  /// 获取到期日期（YYYY-MM-DD）
  String get expiredDate {
    if (expiredAt == 0) return '未订阅';
    final date = DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取距离到期天数
  int get daysUntilExpired {
    if (expiredAt == 0) return 0;
    final expireDate = DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000);
    final now = DateTime.now();
    return expireDate.difference(now).inDays;
  }

  /// 是否已过期
  bool get isExpired => daysUntilExpired < 0;

  /// 获取流量重置时间（YYYY-MM-DD HH:mm）
  String get nextResetTime {
    if (nextResetAt == null) return '暂无';
    final date = DateTime.fromMillisecondsSinceEpoch(nextResetAt! * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 获取到期提示文字
  String get expireInfo {
    if (!hasSubscription) return '未订阅';
    
    final daysText = daysUntilExpired > 0 
        ? '距离到期还有 $daysUntilExpired 天'
        : '已过期';
    
    return '于 $expiredDate 到期，$daysText';
  }

  /// 获取流量重置提示文字
  String get resetInfo {
    if (nextResetAt == null) return '';
    return '已用流量将在 $nextResetTime 重置';
  }

  /// 格式化字节数为KB/MB/GB
  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      // 小于1MB，显示KB
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      // 小于1GB，显示MB
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    } else {
      // 大于1GB，显示GB
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(2)} GB';
    }
  }
}

/// 套餐信息（简化版）
class PlanInfo {
  final int id;
  final int groupId;
  final int transferEnable; // GB
  final String name;
  final Map<String, String?> prices;
  final int sell;
  final int? speedLimit;
  final int? deviceLimit;
  final bool show;
  final int sort;
  final bool renew;
  final String? content;

  PlanInfo({
    required this.id,
    required this.groupId,
    required this.transferEnable,
    required this.name,
    required this.prices,
    required this.sell,
    this.speedLimit,
    this.deviceLimit,
    required this.show,
    required this.sort,
    required this.renew,
    this.content,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> json) {
    return PlanInfo(
      id: json['id'],
      groupId: json['group_id'],
      transferEnable: json['transfer_enable'] ?? 0,
      name: json['name'] ?? '',
      prices: Map<String, String?>.from(json['prices'] ?? {}),
      sell: json['sell'] ?? 0,
      speedLimit: json['speed_limit'],
      deviceLimit: json['device_limit'],
      show: json['show'] == true || json['show'] == 1,
      sort: json['sort'] ?? 0,
      renew: json['renew'] == true || json['renew'] == 1,
      content: json['content'],
    );
  }

  /// 获取流量配额（格式化）
  String get transferEnableFormatted => '${transferEnable}GB/月';
}

