import 'package:flutter/material.dart';
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(
                  child: Text(
                    '暂无可用套餐',
                    style: TextStyle(color: Color(0xFF999999)),
                  ),
                )
              : Column(
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
                    
                    // 套餐列表
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          final plan = _plans[index];
                          final isSelected = _selectedPlanId == plan.id;
                          
                          return _buildPlanCard(plan, isSelected);
                        },
                      ),
                    ),
                    
                    // 底部操作栏
                    _buildBottomBar(),
                  ],
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
                    color: const Color(0xFFFFD700).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
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
            // 套餐标题
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFD700).withOpacity(0.1) : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF999999),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF333333),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '已选',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // 流量信息
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                plan.transferEnableGB,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // 价格选项
            if (isSelected && priceOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: priceOptions.map((option) {
                    final isOptionSelected = _selectedPeriod == option.period;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPeriod = option.period;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isOptionSelected ? const Color(0xFF007AFF) : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isOptionSelected ? const Color(0xFF007AFF) : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Text(
                          '${option.period} ${option.priceYuan}',
                          style: TextStyle(
                            color: isOptionSelected ? Colors.white : const Color(0xFF333333),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
}
