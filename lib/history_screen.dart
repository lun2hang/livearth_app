import 'package:flutter/material.dart';
import 'models/task.dart';
import 'models/supply.dart';
import 'task_detail_screen.dart';
import 'supply_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String title;
  final Future<List<dynamic>> Function() onLoad;

  const HistoryScreen({
    super.key,
    required this.title,
    required this.onLoad,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await widget.onLoad();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text("暂无发布记录", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _buildItemCard(item);
                  },
                ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    String title = "";
    String subtitle = "";
    String date = "";
    IconData icon = Icons.help_outline;
    Color iconColor = Colors.grey;

    if (item is Task) {
      title = item.title;
      subtitle = "预算: \$${item.budget} | 状态: ${item.status}";
      date = item.createdAt.split('T')[0]; // 简单格式化日期
      icon = Icons.lightbulb_outline;
      iconColor = Colors.blue;
    } else if (item is Supply) {
      title = item.title;
      subtitle = "价格: ¥${item.price} | 状态: ${item.status}";
      date = item.createdAt.split('T')[0];
      icon = Icons.camera_roll_outlined;
      iconColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        onTap: () {
          if (item is Task) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: item)));
          } else if (item is Supply) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SupplyDetailScreen(supply: item)));
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text("$subtitle\n发布于: $date", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        isThreeLine: true,
      ),
    );
  }
}