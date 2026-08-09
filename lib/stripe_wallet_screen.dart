import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/stripe_model.dart';
import 'config/stripe_config.dart';
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
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stripe 消费者绑卡'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer ID: ${res.customerId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Text('Client Secret:\n${res.clientSecret}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              const Text('绑卡 SetupIntent 已就绪。正式环境下将拉起 Stripe PaymentSheet 供用户安全输入信用卡号。', style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadStatus();
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建绑卡 SetupIntent 失败，请检查网络或后端配置')),
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
            SnackBar(content: Text('无法打开链接: ${res.url}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('跳转失败: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建 Stripe Connect 引导链接失败，请检查后端配置')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('支付与收款设置 (Stripe)'),
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
                  // Stripe 公钥配置提示卡片
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Stripe 配置信息',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '当前测试 Publishable Key:\n${StripeConfig.publishableKey}',
                          style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blue[800]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. 消费者绑卡板块 (Consumer Payment)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.credit_card, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text('付款方式 (消费者/需求方)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stripe Customer 账号'),
                            Text(
                              _status?.hasCustomerId == true ? '已创建' : '未绑定',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _status?.hasCustomerId == true ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (_status?.stripeCustomerId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${_status!.stripeCustomerId}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isActionLoading ? null : _handleSetupPaymentCard,
                            icon: const Icon(Icons.add_card, size: 18),
                            label: Text(_status?.hasCustomerId == true ? '添加/更新支付卡' : '绑定支付卡'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. 供给者收款板块 (Provider Connect Payout)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text('收款账户 (供给者/服务方)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stripe Connect 状态'),
                            _buildConnectStatusBadge(),
                          ],
                        ),
                        if (_status?.stripeConnectId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Express Acct: ${_status!.stripeConnectId}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          '使用 Stripe Connect Express 托管方案，身份实名认证 (KYC) 与银行卡全由 Stripe 安全处理。',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isActionLoading ? null : _handleConnectPayoutOnboarding,
                            icon: const Icon(Icons.open_in_browser, size: 18),
                            label: Text(_status?.stripeConnectOnboarded == true ? '管理/查看收款账户' : '设置 Stripe Connect 收款账户'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
        child: const Text('🟢 认证已完成', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    if (_status?.hasConnectAccount == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(4)),
        child: const Text('🟡 待完成认证', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
      child: const Text('⚪️ 未绑定', style: TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }
}
