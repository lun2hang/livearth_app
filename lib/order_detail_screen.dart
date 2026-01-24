import 'package:flutter/material.dart';
import 'models/order.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderWithDetails order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isTaskOrder = order.taskId != null;
    final typeLabel = isTaskOrder ? "需求订单" : "供给订单";
    final relatedId = isTaskOrder ? order.taskId : order.supplyId;

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
                    color: order.status == 'completed' ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "订单状态: ${order.status}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "¥${order.amount}",
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
                  _buildInfoRow("订单编号", "#${order.id}"),
                  const SizedBox(height: 12),
                  _buildInfoRow("订单类型", typeLabel),
                  const SizedBox(height: 12),
                  _buildInfoRow("关联ID", "#$relatedId"),
                  const SizedBox(height: 12),
                  _buildInfoRow("创建时间", _formatTime(order.createdAt)),
                  if (order.startTime != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow("开始时间", _formatTime(order.startTime!)),
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
                  _buildUserRow("消费者", order.consumer),
                  const SizedBox(height: 12),
                  _buildUserRow("供给者", order.provider),
                ],
              ),
            ),
          ],
        ),
      ),
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
              Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text("ID: ${user.id}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
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