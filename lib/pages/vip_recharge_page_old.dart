import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/plan_model.dart';

class VipRechargePage extends StatefulWidget {
  const VipRechargePage({super.key});

  @override
  State<VipRechargePage> createState() => _VipRechargePageState();
}

class _VipRechargePageState extends State<VipRechargePage> {
  final ApiService _apiService = ApiService();
  
  int? _selectedPlanId;
  String? _selectedPeriod; // 选中的周期（月付、季付等）
  String _selectedPaymentMethod = 'alipay';
  
  List<PlanModel> _plans = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'alipay',
      'name': '支付宝',
      'icon': Icons.account_balance_wallet,
      'color': const Color(0xFF1677FF),
    },
    {
      'id': 'wechat',
      'name': '微信支付',
      'icon': Icons.chat,
      'color': const Color(0xFF07C160),
    },
    {
      'id': 'unionpay',
      'name': '银联支付',
      'icon': Icons.credit_card,
      'color': const Color(0xFFE60012),
    },
  ];
  
  @override
  void initState() {
    super.initState();
    _loadPlans();
  }
  
  /// 加载套餐列表
  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _apiService.fetchPlans();
      
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'VIP充值',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // VIP特权说明
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '升级VIP会员',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '享受高速代理、专属节点等特权',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 套餐选择
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _plans.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无可用套餐',
                          style: TextStyle(color: Color(0xFF999999)),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '选择套餐',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // 套餐卡片
                            ..._plans.map((plan) {
                              final isSelected = _selectedPlanId == plan.id;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPlanId = plan.id;
                                    // 重置选中的周期为第一个可用选项
                                    final priceOptions = plan.getAvailablePriceOptions();
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            if (plan['popular'])
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF6B6B),
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    '推荐',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan['name'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...plan['features'].map((feature) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                color: Color(0xFF4CAF50),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                feature,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF666666),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '¥${plan['price']}',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF6B6B),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '¥${plan['originalPrice']}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF999999),
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        plan['duration'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // 添加选择指示器
                            if (isSelected)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFD700),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 24),
                  
                  // 支付方式
                  const Text(
                    '支付方式',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  ..._paymentMethods.map((method) {
                    final isSelected = _selectedPaymentMethod == method['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? method['color'] : const Color(0xFFE0E0E0),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          method['icon'],
                          color: method['color'],
                        ),
                        title: Text(
                          method['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: method['color'],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedPaymentMethod = method['id'];
                          });
                        },
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // 支付按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 价格信息
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '实付金额',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF666666),
                        ),
                      ),
                      Text(
                        '¥${selectedPlan['price']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // 支付按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // 处理支付逻辑
                      _showPaymentDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '立即支付',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认支付'),
        content: Text('确认支付 ¥${_vipPlans.firstWhere((plan) => plan['id'] == _selectedPlan)['price']} 购买VIP会员？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('支付成功！VIP会员已激活')),
              );
              Navigator.pop(context);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
} 