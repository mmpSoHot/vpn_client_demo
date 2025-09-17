import 'package:flutter/material.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final List<_UsageRecord> _items = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isRefreshing = true;
      _hasMore = true;
      _page = 1;
    });
    final data = await _fetchPage(_page, _pageSize);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(data);
      _hasMore = data.length == _pageSize;
      _isRefreshing = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _page += 1;
    });
    final data = await _fetchPage(_page, _pageSize);
    if (!mounted) return;
    setState(() {
      _items.addAll(data);
      _hasMore = data.length == _pageSize;
      _isLoading = false;
    });
  }

  Future<List<_UsageRecord>> _fetchPage(int page, int pageSize) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final List<_UsageRecord> result = [];
    final DateTime today = DateTime.now();
    final int start = (page - 1) * pageSize;
    for (int i = 0; i < pageSize; i++) {
      final day = today.subtract(Duration(days: start + i));
      final double upMB = 5 + (start + i) * 0.3;
      final double downMB = 600 + ((start + i) * 4.2);
      final double ratio = 0.8;
      result.add(_UsageRecord(date: day, uploadMB: upMB, downloadMB: downMB, ratio: ratio));
    }
    return result;
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatMB(double mb) {
    return '${mb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '使用统计',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index == _items.length) {
              if (_isRefreshing) {
                return const SizedBox.shrink();
              }
              if (_isLoading) {
                return _buildLoadingFooter();
              }
              if (!_hasMore) {
                return _buildNoMoreFooter();
              }
              return const SizedBox.shrink();
            }
            final item = _items[index];
            final String dateStr = _formatDate(item.date);
            final double totalMB = (item.uploadMB + item.downloadMB) * item.ratio;
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '记录时间',
                        style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetric(label: '实际上行', value: _formatMB(item.uploadMB), color: const Color(0xFF007AFF)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetric(label: '实际下行', value: _formatMB(item.downloadMB), color: const Color(0xFF4CAF50)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetric(label: '扣费倍率', value: '${item.ratio.toStringAsFixed(2)} x', color: const Color(0xFFFF9800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetric(label: '总计', value: _formatMB(totalMB), color: const Color(0xFF9C27B0)),
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

  Widget _buildLoadingFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('加载中...')
        ],
      ),
    );
  }

  Widget _buildNoMoreFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          '没有更多了',
          style: TextStyle(color: Color(0xFF999999)),
        ),
      ),
    );
  }
}

class _UsageRecord {
  final DateTime date;
  final double uploadMB;
  final double downloadMB;
  final double ratio;

  _UsageRecord({required this.date, required this.uploadMB, required this.downloadMB, required this.ratio});
}


