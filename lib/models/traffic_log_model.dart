/// 流量记录数据模型
class TrafficLogModel {
  final int d;              // 实际下行（字节）
  final int u;              // 实际上行（字节）
  final int recordAt;       // 记录时间（时间戳）
  final String serverRate;  // 扣费倍率
  final int userId;

  TrafficLogModel({
    required this.d,
    required this.u,
    required this.recordAt,
    required this.serverRate,
    required this.userId,
  });

  factory TrafficLogModel.fromJson(Map<String, dynamic> json) {
    return TrafficLogModel(
      d: json['d'] ?? 0,
      u: json['u'] ?? 0,
      recordAt: json['record_at'] ?? 0,
      serverRate: json['server_rate'] ?? '1.00',
      userId: json['user_id'] ?? 0,
    );
  }

  /// 获取记录日期（YYYY-MM-DD格式）
  String get recordDate {
    final date = DateTime.fromMillisecondsSinceEpoch(recordAt * 1000);
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 获取扣费倍率（格式化）
  String get rateFormatted {
    return '${double.parse(serverRate).toStringAsFixed(2)} x';
  }

  /// 获取下行流量（格式化为MB或GB）
  String get downloadFormatted {
    return _formatBytes(d);
  }

  /// 获取上行流量（格式化为MB或GB）
  String get uploadFormatted {
    return _formatBytes(u);
  }

  /// 计算总计流量（字节）
  int get total {
    return d + u;
  }

  /// 获取总计流量（格式化为MB或GB）
  String get totalFormatted {
    return _formatBytes(total);
  }

  /// 计算扣费总计（按倍率计算）
  int get billedTotal {
    final rate = double.parse(serverRate);
    return (total * rate).toInt();
  }

  /// 获取扣费总计（格式化为MB或GB）
  String get billedTotalFormatted {
    return _formatBytes(billedTotal);
  }

  /// 格式化字节数为MB或GB
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

