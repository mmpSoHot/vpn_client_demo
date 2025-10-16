import 'package:flutter/material.dart';
import '../models/plan_model.dart';
import '../services/api_service.dart';

class PlanCheckoutPage extends StatefulWidget {
  final PlanModel? plan; // 可空，若传ID则运行时再拉取
  final int? planId;
  final String? initialPeriod;
  const PlanCheckoutPage({super.key, this.plan, this.planId, this.initialPeriod});

  @override
  State<PlanCheckoutPage> createState() => _PlanCheckoutPageState();
}

class _PlanCheckoutPageState extends State<PlanCheckoutPage> {
  late List<PriceOption> _options;
  String? _period;
  final TextEditingController _couponCtrl = TextEditingController();
  bool _couponVerified = false;
  Map<String, dynamic>? _couponData;
  Map<String, dynamic>? _unpaidOrder;
  final ApiService _api = ApiService();
  PlanModel? _plan;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    if (_plan != null) {
      _initFromPlan(_plan!);
    } else if (widget.planId != null) {
      _loadPlan(widget.planId!);
    } else {
      _options = [];
      _loading = false;
    }
  }

  PriceOption? get _currentOption {
    if (_period == null) return null;
    for (final o in _options) {
      if (o.period == _period) return o;
    }
    return null;
  }

  Future<void> _loadPlan(int id) async {
    final resp = await _api.fetchPlanById(id);
    if (resp.success && resp.data != null) {
      setState(() {
        _plan = PlanModel.fromJson(resp.data);
      });
      _initFromPlan(_plan!);
    } else {
      setState(() { _loading = false; });
    }
  }

  void _initFromPlan(PlanModel plan) {
    _options = plan.getAvailablePriceOptions();
    _period = widget.initialPeriod ?? (_options.isNotEmpty ? _options.first.period : null);
    setState(() { _loading = false; });
    _checkUnpaidOrder();
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentOption;
    if (_loading || _plan == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('套餐详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_plan!.name} - ${_plan!.transferEnableGB}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('流量: ${_plan!.transferEnableGB}', style: const TextStyle(color: Color(0xFF6B7280))),
                      const SizedBox(width: 12),
                      Text('设备: ${_plan!.deviceLimit != null ? '${_plan!.deviceLimit} 台' : '以套餐说明为准'}',
                          style: const TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: const [
                Text('选择付款周期', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _options.map((o) {
                final selected = _period == o.period;
                return GestureDetector(
                  onTap: () => setState(() => _period = o.period),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEFF2FF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? const Color(0xFF5B7CFF) : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(o.period, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF5B7CFF) : const Color(0xFF374151))),
                            if (selected) const Spacer(),
                            if (selected) const Icon(Icons.check_circle, size: 16, color: Color(0xFF5B7CFF)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(o.priceYuan, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                            const SizedBox(width: 4),
                            const Text('¥/每月', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: const [
                Text('使用优惠券', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponCtrl,
                    decoration: InputDecoration(
                      hintText: '请输入优惠码',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF5B7CFF), width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (_plan == null) return;
                    final code = _couponCtrl.text.trim();
                    if (code.isEmpty) return;
                    final resp = await _api.checkCoupon(planId: _plan!.id, code: code);
                    final ok = resp.success;
                    setState(() {
                      _couponVerified = ok;
                      _couponData = ok ? resp.data as Map<String, dynamic>? : null;
                    });
                    if (!mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(resp.message ?? '优惠券无效'),
                          backgroundColor: const Color(0xFFF44336),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _couponVerified ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                    foregroundColor: _couponVerified ? Colors.white : const Color(0xFF6B7280),
                    minimumSize: const Size(84, 44),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('验证'),
                ),
              ],
            ),
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('支付总计', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        final baseCents = current?.price ?? 0;
                        final discountCents = _calcDiscount(baseCents);
                        final finalCents = (baseCents - discountCents).clamp(0, 1<<31);
                        String toYuan(int cents) => '¥' + (cents / 100).toStringAsFixed(2);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (discountCents > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      (_couponData != null && _couponData!['name'] != null)
                                          ? (_couponData!['name'].toString())
                                          : '优惠券',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('-' + toYuan(discountCents),
                                        style: const TextStyle(fontSize: 12, color: Color(0xFFF44336), fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            Text(toYuan(finalCents),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: current == null ? null : () async {
                    if (_plan == null || current == null) return;
                    if (_unpaidOrder != null) {
                      final confirm = await _confirmCancelPrevOrder();
                      if (confirm == null) return; // 跳转到订单页或返回
                      if (!confirm) return;
                      final tradeNo = _unpaidOrder!['trade_no']?.toString();
                      if (tradeNo != null && tradeNo.isNotEmpty) {
                        final cancelResp = await _api.cancelOrderByTradeNo(tradeNo);
                        if (cancelResp.success && cancelResp.data == true) {
                          // 刷新当前页面数据并中断本次下单
                          await _loadPlan(_plan!.id);
                          await _checkUnpaidOrder();
                          return;
                        }
                      }
                      setState(() { _unpaidOrder = null; });
                    }
                    final key = _periodKey(current.period);
                    final resp = await _api.createOrder(planId: _plan!.id, periodKey: key);
                    final ok = resp.success;
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? '订单创建成功' : (resp.message ?? '下单失败')),
                        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFF44336),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B5BCE),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('下单'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _periodKey(String periodLabel) {
    switch (periodLabel) {
      case '月付':
        return 'month_price';
      case '季付':
        return 'quarter_price';
      case '半年付':
        return 'half_year_price';
      case '年付':
        return 'year_price';
      default:
        return 'month_price';
    }
  }

  int _calcDiscount(int baseCents) {
    if (!_couponVerified || _couponData == null || baseCents <= 0) return 0;
    final type = _couponData!['type'];
    final value = _couponData!['value'];
    if (type == 1) {
      // 固定金额（元为单位? 接口用分/元不确定，按元换分）
      final amountYuan = (value is num) ? value.toDouble() : 0.0;
      return (amountYuan * 100).round().clamp(0, baseCents);
    } else if (type == 2) {
      // 百分比
      final percent = (value is num) ? value.toDouble() : 0.0; // 10 => 10%
      final d = (baseCents * (percent / 100)).round();
      return d.clamp(0, baseCents);
    }
    return 0;
  }

  Future<void> _checkUnpaidOrder() async {
    final resp = await _api.fetchOrders();
    if (!resp.success || resp.data == null) return;
    final list = resp.data as List<dynamic>;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      if (m['status'] == 0) {
        setState(() { _unpaidOrder = m; });
        break;
      }
    }
  }

  Future<bool?> _confirmCancelPrevOrder() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('存在未完成订单'),
          content: const Text('您还有未完成的订单，购买前需要先取消。确定要取消之前的订单吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, null); // 交给调用处处理跳转
              },
              child: const Text('我的订单'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(254, 75, 72, 1), foregroundColor: Colors.white),
              child: const Text('确认取消'),
            ),
          ],
        );
      },
    );
  }
}


