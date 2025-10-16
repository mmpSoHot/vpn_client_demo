import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'plan_checkout_page.dart';
import '../services/api_service.dart';
import '../models/plan_model.dart';
import '../utils/auth_helper.dart';

class VipRechargePage extends StatefulWidget {
  const VipRechargePage({super.key});

  @override
  State<VipRechargePage> createState() => _VipRechargePageState();
}

class _VipRechargePageState extends State<VipRechargePage> {
  final ApiService _apiService = ApiService();
  
  int? _selectedPlanId;
  String? _selectedPeriod;
  
  List<PlanModel> _plans = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  // 注意事项改为 HTML 渲染，因此不再需要解析函数
  
  /// 加载套餐列表
  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _apiService.fetchPlans();
      
      // 检查是否未授权
      if (mounted && !await AuthHelper.checkAndHandleAuth(context, response)) {
        return; // 未授权，已自动跳转到登录页面
      }
      
      if (response.success && response.data != null) {
        final List<dynamic> plansList = response.data;
        final plans = plansList.map((json) => PlanModel.fromJson(json)).toList();
        
        // 过滤出可显示和可售卖的套餐，并按sort排序
        final visiblePlans = plans.where((p) => p.show && p.sell).toList();
        visiblePlans.sort((a, b) => a.sort.compareTo(b.sort));
        
        if (mounted) {
          setState(() {
            _plans = visiblePlans;
            _isLoading = false;
            
            // 默认选中第一个套餐和第一个价格选项
            if (_plans.isNotEmpty) {
              _selectedPlanId = _plans[0].id;
              final priceOptions = _plans[0].getAvailablePriceOptions();
              if (priceOptions.isNotEmpty) {
                _selectedPeriod = priceOptions[0].period;
              }
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? '加载套餐失败'),
              backgroundColor: const Color(0xFFF44336),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载套餐失败: ${e.toString()}'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(
                  child: Text(
                    '暂无可用套餐',
                    style: TextStyle(color: Color(0xFF999999)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    final isSelected = _selectedPlanId == plan.id;                          
                    return _buildPlanCard(plan, isSelected);
                  },
                ),
    );
  }

  /// 构建套餐卡片
  Widget _buildPlanCard(PlanModel plan, bool isSelected) {
    final priceOptions = plan.getAvailablePriceOptions();
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = plan.id;
          // 重置选中的周期为第一个可用选项
          if (priceOptions.isNotEmpty) {
            _selectedPeriod = priceOptions[0].period;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 套餐标题
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromRGBO(254, 75, 72, 1),   // 主色 rgb(254,75,72)
                    Color.fromRGBO(245, 67, 63, 1),   // 相近加深色
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${plan.name} - ${plan.transferEnableGB}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 右侧价格（跟随选中的周期变化）
                  Builder(
                    builder: (_) {
                      final opts = plan.getAvailablePriceOptions();
                      final current = (_selectedPlanId == plan.id && _selectedPeriod != null)
                          ? opts.firstWhere(
                              (o) => o.period == _selectedPeriod,
                              orElse: () => opts.isNotEmpty ? opts.first : PriceOption(period: '月付', price: 0, priceYuan: '¥0.00', months: 1),
                            )
                          : (opts.isNotEmpty ? opts.first : PriceOption(period: '月付', price: 0, priceYuan: '¥0.00', months: 1));
                      return Row(
                        children: [
                          Text(
                            current.priceYuan,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            current.period,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
       

            // 注意事项（HTML 渲染）
            if ((plan.content ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Html(
                    data: plan.content,
                    style: {
                      'ul': Style(margin: Margins.zero, padding: HtmlPaddings.zero, listStyleType: ListStyleType.none),
                      'li': Style(display: Display.block, margin: Margins.only(bottom: 6)),
                      'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero, fontSize: FontSize(13), color: const Color(0xFF4B5563)),
                    },
                  ),
                ),
              ),


            // 卡片内购买按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedPlanId = plan.id;
                    });
                    final opts = plan.getAvailablePriceOptions();
                    final init = (_selectedPeriod != null && opts.any((o) => o.period == _selectedPeriod))
                        ? _selectedPeriod
                        : (opts.isNotEmpty ? opts.first.period : null);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlanCheckoutPage(planId: plan.id, initialPeriod: init),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(254, 75, 72, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('购买', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomBar() {
    if (_selectedPlanId == null || _plans.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 获取选中的套餐和价格
    final selectedPlan = _plans.firstWhere(
      (p) => p.id == _selectedPlanId,
      orElse: () => _plans.first,
    );
    
    final priceOptions = selectedPlan.getAvailablePriceOptions();
    final selectedOption = priceOptions.firstWhere(
      (o) => o.period == _selectedPeriod,
      orElse: () => priceOptions.isNotEmpty 
          ? priceOptions.first 
          : PriceOption(period: '', price: 0, priceYuan: '¥0.00', months: 0),
    );
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '总计',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedOption.priceYuan,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF44336),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _handlePayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                '立即购买',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 处理支付
  void _handlePayment() {
    if (_selectedPlanId == null || _selectedPeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择套餐和周期'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
      return;
    }
    
    // TODO: 调用支付API
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在跳转到支付页面...\n套餐ID: $_selectedPlanId, 周期: $_selectedPeriod'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  /// 打开周期选择抽屉（卡片式，参照设计图）
  void _showPeriodPicker(PlanModel plan) {
    final options = plan.getAvailablePriceOptions();
    if (options.isEmpty) {
      _handlePayment();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String tempPeriod = _selectedPeriod ?? options.first.period;
        bool verified = false;
        String _perDay(PriceOption o) {
          final days = (o.months * 30).clamp(1, 10000);
          final per = o.price / 100 / days;
          return '¥' + per.toStringAsFixed(2) + '/天';
        }
        int? _originPrice(PriceOption o) {
          if (o.months > 1 && plan.monthPrice != null) {
            return plan.monthPrice! * o.months;
          }
          return null;
        }
        return StatefulBuilder(builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.38,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (_, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '(${plan.name}) 选择周期',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 118,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        physics: const BouncingScrollPhysics(),
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final o = options[i];
                          final selected = tempPeriod == o.period;
                          final origin = _originPrice(o);
                          return GestureDetector(
                            onTap: () => setSheetState(() => tempPeriod = o.period),
                            child: Container(
                              width: 140,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFEFF2FF) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? const Color(0xFF5B7CFF) : const Color(0xFFE5E7EB),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.period,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selected ? const Color(0xFF5B7CFF) : const Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(o.priceYuan, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                      const SizedBox(width: 4),
                                      const Text('/ 月', style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (origin != null && origin > o.price)
                                    Text(
                                      '¥' + (origin / 100).toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  const Spacer(),
                                  Text(
                                    _perDay(o),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(tempPeriod.isEmpty ? '请选择付款周期' : '已选择：$tempPeriod',
                                  style: const TextStyle(color: Color(0xFF6B7280))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              setSheetState(() => verified = true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: verified ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                              foregroundColor: verified ? Colors.white : const Color(0xFF6B7280),
                              minimumSize: const Size(84, 44),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('验证'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: verified
                                ? () {
                                    setState(() {
                                      _selectedPeriod = tempPeriod;
                                    });
                                    Navigator.pop(context);
                                    _handlePayment();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5B7CFF),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(108, 44),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('创建订单'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }
}

/// 轻量信息瓦片
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile({required this.icon, required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF5B7CFF), size: 18),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        ],
      ),
    );
  }
}

/// 注意事项行
class _NoteRow extends StatelessWidget {
  final String icon;
  final String text;
  const _NoteRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
