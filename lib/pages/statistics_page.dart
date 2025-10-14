import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/traffic_log_model.dart';
import '../utils/auth_helper.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final ApiService _apiService = ApiService();
  final List<TrafficLogModel> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTrafficLog();
  }

  /// 加载流量记录
  Future<void> _loadTrafficLog() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _apiService.getTrafficLog();
      
      // 检查是否未授权
      if (mounted && !await AuthHelper.checkAndHandleAuth(context, response)) {
        return; // 未授权，已自动跳转到登录页面
      }
      
      if (response.success && response.data != null) {
        final List<dynamic> logList = response.data;
        final logs = logList.map((json) => TrafficLogModel.fromJson(json)).toList();
        
        // 按日期分组并合并同一天的记录
        final Map<String, List<TrafficLogModel>> groupedByDate = {};
        for (var log in logs) {
          final date = log.recordDate;
          if (!groupedByDate.containsKey(date)) {
            groupedByDate[date] = [];
          }
          groupedByDate[date]!.add(log);
        }
        
        // 合并每一天的记录
        final mergedLogs = <TrafficLogModel>[];
        groupedByDate.forEach((date, dayLogs) {
          // 计算该天的总流量（已应用扣费倍率）
          int totalD = 0;
          int totalU = 0;
          
          for (var log in dayLogs) {
            final rate = double.parse(log.serverRate);
            totalD += (log.d * rate).toInt();
            totalU += (log.u * rate).toInt();
          }
          
          // 使用加权平均倍率
          double totalRate = 1.0;
          if (dayLogs.isNotEmpty) {
            double totalBytes = 0;
            double weightedRate = 0;
            for (var log in dayLogs) {
              final bytes = log.d + log.u;
              final rate = double.parse(log.serverRate);
              totalBytes += bytes;
              weightedRate += bytes * rate;
            }
            totalRate = totalBytes > 0 ? weightedRate / totalBytes : 1.0;
          }
          
          // 创建合并后的记录
          mergedLogs.add(TrafficLogModel(
            d: totalD,
            u: totalU,
            recordAt: dayLogs.first.recordAt,
            serverRate: totalRate.toStringAsFixed(2),
            userId: dayLogs.first.userId,
          ));
        });
        
        // 按日期降序排序
        mergedLogs.sort((a, b) => b.recordAt.compareTo(a.recordAt));
        
        if (mounted) {
          setState(() {
            _items.clear();
            _items.addAll(mergedLogs);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          if (response.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.message!),
                backgroundColor: const Color(0xFFF44336),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: ${e.toString()}'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '流量统计',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: _loadTrafficLog,
        child: _isLoading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          '暂无使用记录',
                          style: TextStyle(color: Color(0xFF999999)),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 记录时间
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '记录时间',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                                ),
                                Text(
                                  item.recordDate,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 上行和下行
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetric(
                                    label: '实际上行',
                                    value: item.uploadFormatted,
                                    color: const Color(0xFF007AFF),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetric(
                                    label: '实际下行',
                                    value: item.downloadFormatted,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 扣费倍率和总计
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetric(
                                    label: '扣费倍率',
                                    value: item.rateFormatted,
                                    color: const Color(0xFFFF9800),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetric(
                                    label: '总计',
                                    value: item.totalFormatted,
                                    color: const Color(0xFF9C27B0),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildMetric({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
