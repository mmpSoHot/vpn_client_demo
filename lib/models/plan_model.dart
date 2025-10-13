/// 套餐数据模型
class PlanModel {
  final int id;
  final int groupId;
  final String name;
  final List<String> tags;
  final String? content;
  final int? monthPrice;       // 单位：分
  final int? quarterPrice;     // 单位：分
  final int? halfYearPrice;    // 单位：分
  final int? yearPrice;        // 单位：分
  final int? twoYearPrice;     // 单位：分
  final int? threeYearPrice;   // 单位：分
  final int? onetimePrice;     // 单位：分
  final int? resetPrice;       // 单位：分
  final int? capacityLimit;
  final int? transferEnable;   // 单位：GB
  final int? speedLimit;
  final int? deviceLimit;
  final bool show;
  final bool sell;
  final bool renew;
  final String? resetTrafficMethod;
  final int sort;
  final int createdAt;
  final int updatedAt;

  PlanModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.tags,
    this.content,
    this.monthPrice,
    this.quarterPrice,
    this.halfYearPrice,
    this.yearPrice,
    this.twoYearPrice,
    this.threeYearPrice,
    this.onetimePrice,
    this.resetPrice,
    this.capacityLimit,
    this.transferEnable,
    this.speedLimit,
    this.deviceLimit,
    required this.show,
    required this.sell,
    required this.renew,
    this.resetTrafficMethod,
    required this.sort,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'],
      groupId: json['group_id'],
      name: json['name'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      content: json['content'],
      monthPrice: json['month_price'],
      quarterPrice: json['quarter_price'],
      halfYearPrice: json['half_year_price'],
      yearPrice: json['year_price'],
      twoYearPrice: json['two_year_price'],
      threeYearPrice: json['three_year_price'],
      onetimePrice: json['onetime_price'],
      resetPrice: json['reset_price'],
      capacityLimit: json['capacity_limit'],
      transferEnable: json['transfer_enable'],
      speedLimit: json['speed_limit'],
      deviceLimit: json['device_limit'],
      show: json['show'] ?? true,
      sell: json['sell'] ?? true,
      renew: json['renew'] ?? true,
      resetTrafficMethod: json['reset_traffic_method'],
      sort: json['sort'] ?? 0,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  /// 获取月付价格（元）
  String get monthPriceYuan => monthPrice != null ? '¥${(monthPrice! / 100).toStringAsFixed(2)}' : '-';

  /// 获取季付价格（元）
  String get quarterPriceYuan => quarterPrice != null ? '¥${(quarterPrice! / 100).toStringAsFixed(2)}' : '-';

  /// 获取半年付价格（元）
  String get halfYearPriceYuan => halfYearPrice != null ? '¥${(halfYearPrice! / 100).toStringAsFixed(2)}' : '-';

  /// 获取年付价格（元）
  String get yearPriceYuan => yearPrice != null ? '¥${(yearPrice! / 100).toStringAsFixed(2)}' : '-';

  /// 获取流量（GB）
  String get transferEnableGB => transferEnable != null ? '${transferEnable}GB/月' : '不限';

  /// 获取可用的价格选项
  List<PriceOption> getAvailablePriceOptions() {
    final options = <PriceOption>[];
    
    if (monthPrice != null) {
      options.add(PriceOption(
        period: '月付',
        price: monthPrice!,
        priceYuan: monthPriceYuan,
        months: 1,
      ));
    }
    
    if (quarterPrice != null) {
      options.add(PriceOption(
        period: '季付',
        price: quarterPrice!,
        priceYuan: quarterPriceYuan,
        months: 3,
      ));
    }
    
    if (halfYearPrice != null) {
      options.add(PriceOption(
        period: '半年付',
        price: halfYearPrice!,
        priceYuan: halfYearPriceYuan,
        months: 6,
      ));
    }
    
    if (yearPrice != null) {
      options.add(PriceOption(
        period: '年付',
        price: yearPrice!,
        priceYuan: yearPriceYuan,
        months: 12,
      ));
    }
    
    return options;
  }
}

/// 价格选项
class PriceOption {
  final String period;   // 周期（月付、季付等）
  final int price;       // 价格（分）
  final String priceYuan; // 价格（元，格式化后）
  final int months;      // 月数

  PriceOption({
    required this.period,
    required this.price,
    required this.priceYuan,
    required this.months,
  });
}

