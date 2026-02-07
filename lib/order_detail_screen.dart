import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/order.dart';
import 'main.dart'; // 导入 MockAPI
import 'call_screen.dart';
import 'chat_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderWithDetails order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    const storage = FlutterSecureStorage();
    final uid = await storage.read(key: 'user_id');
    if (mounted) setState(() => _currentUserId = uid);
  }

  Future<void> _handleCancel() async {
    // 弹窗确认
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text('取消后无法恢复，您确定要取消这个订单吗？', textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await MockAPI.cancelEntry(widget.order.id, 'order');
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('订单已取消')));
        Navigator.pop(context, true); // 返回 true 表示状态已改变
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取消失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTaskOrder = widget.order.taskId != null;
    final typeLabel = isTaskOrder ? "需求订单" : "供给订单";
    final relatedId = isTaskOrder ? widget.order.taskId : widget.order.supplyId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('订单详情'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: widget.order.status == 'completed' ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "订单状态: ${widget.order.status}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "¥${widget.order.amount}",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 基本信息
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
                  const Text("基本信息", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 24),
                  _buildInfoRow("订单编号", "#${widget.order.id}"),
                  const SizedBox(height: 12),
                  _buildInfoRow("订单类型", typeLabel),
                  const SizedBox(height: 12),
                  _buildInfoRow("关联ID", "#$relatedId"),
                  const SizedBox(height: 12),
                  _buildInfoRow("创建时间", _formatTime(widget.order.createdAt)),
                  if (widget.order.startTime != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow("开始时间", _formatTime(widget.order.startTime!)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 交易方信息
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
                  const Text("交易方信息", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 24),
                  _buildUserRow("消费者", widget.order.consumer),
                  const SizedBox(height: 12),
                  _buildUserRow("供给者", widget.order.provider),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ['created', 'live_start'].contains(widget.order.status)
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 新增的“进入视频”按钮
                SizedBox(
                  width: MediaQuery.of(context).size.width / 3,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallScreen(
                            orderId: widget.order.id,
                            isProvider: widget.order.provider.id == _currentUserId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green,
                      disabledBackgroundColor: Colors.green.shade50,
                      disabledForegroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('进入视频', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 20),
                // 已有的“取消订单”按钮
                SizedBox(
                  width: MediaQuery.of(context).size.width / 3,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey,
                      side: BorderSide(color: Colors.grey.shade300),
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('取消订单', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildUserRow(String role, UserInfo user) {
    final isOther = _currentUserId != null && user.id != _currentUserId;
    return Row(
      children: [
        CircleAvatar(
          backgroundImage: user.avatar != null ? NetworkImage(user.avatar!) : null,
          radius: 20,
          child: user.avatar == null ? const Icon(Icons.person, color: Colors.grey) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(user.nickname ?? user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
        if (isOther)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
            onPressed: () {
              if (_currentUserId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      orderId: widget.order.id,
                      currentUserId: _currentUserId!,
                      otherUserName: user.nickname ?? user.username,
                      otherUserId: user.id,
                    ),
                  ),
                );
              }
            },
          ),
      ],
    );
  }

  String _formatTime(String iso) {
    try {
      if (!iso.endsWith('Z')) iso += 'Z';
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return iso;
    }
  }
}