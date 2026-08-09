import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/stripe_model.dart';
import 'main.dart'; // 导入 MockAPI

class StripeWalletScreen extends StatefulWidget {
  const StripeWalletScreen({super.key});

  @override
  State<StripeWalletScreen> createState() => _StripeWalletScreenState();
}

class _StripeWalletScreenState extends State<StripeWalletScreen> {
  StripeStatusResponse? _status;
  bool _isLoading = true;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await MockAPI.fetchStripeStatus();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSetupPaymentCard() async {
    setState(() => _isActionLoading = true);
    final res = await MockAPI.createStripeSetupIntent();
    setState(() => _isActionLoading = false);

    if (!mounted) return;
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已成功发起绑卡。正式环境下将拉起 Stripe 原生支付组件。')),
      );
      _loadStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络连接异常，请重试')),
      );
    }
  }

  Future<void> _handleConnectPayoutOnboarding() async {
    setState(() => _isActionLoading = true);
    final res = await MockAPI.createStripeConnectAccountLink();
    setState(() => _isActionLoading = false);

    if (!mounted) return;
    if (res != null && res.url.isNotEmpty) {
      final uri = Uri.parse(res.url);
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开认证链接，请检查浏览器配置')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('打开页面失败: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生成收款账户链接失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('支付与收款设置'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 付款方式 (Consumer Payment Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.credit_card_outlined, color: Colors.blue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text('付款方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _status?.hasCustomerId == true ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _status?.hasCustomerId == true ? '已绑定' : '未绑定',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _status?.hasCustomerId == true ? Colors.green : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '用于发布需求与预订供给时的预授权冻结与服务结算。',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isActionLoading ? null : _handleSetupPaymentCard,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(_status?.hasCustomerId == true ? '更换支付卡' : '绑定支付卡', style: const TextStyle(fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. 收款账户 (Provider Stripe Connect)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.orange, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text('收款账户', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            _buildConnectStatusBadge(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '用于接收接单完成后的收益转账。由 Stripe 安全托管身份认证与资金结算。',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isActionLoading ? null : _handleConnectPayoutOnboarding,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              _status?.stripeConnectOnboarded == true ? '管理收款账户' : '设置收款账户',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectStatusBadge() {
    if (_status?.stripeConnectOnboarded == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: const Text('已绑定', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    if (_status?.hasConnectAccount == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Text('待认证', style: TextStyle(color: Colors.amber[800], fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text('未绑定', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
    );
  }
}
