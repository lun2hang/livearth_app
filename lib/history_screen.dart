import 'package:flutter/material.dart';
import 'models/task.dart';
import 'models/supply.dart';
import 'task_detail_screen.dart';
import 'supply_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String title;
  final Future<List<dynamic>> Function() onLoad;

  const HistoryScreen({super.key, required this.title, required this.onLoad});

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
    setState(() => _isLoading = true);
    try {
      final items = await widget.onLoad();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  // 本地更新列表项状态
  void _handleItemChange(int id, String newStatus) {
    final index = _items.indexWhere((e) => (e is Supply && e.id == id) || (e is Task && e.id == id));
    if (index != -1) {
      setState(() {
        final item = _items[index];
        if (item is Supply) {
          _items[index] = Supply(
            id: item.id,
            userId: item.userId,
            title: item.title,
            description: item.description,
            lat: item.lat,
            lng: item.lng,
            rating: item.rating,
            price: item.price,
            status: newStatus,
            createdAt: item.createdAt,
            validFrom: item.validFrom,
            validTo: item.validTo,
          );
        } else if (item is Task) {
          _items[index] = Task(
            id: item.id,
            userId: item.userId,
            title: item.title,
            description: item.description,
            lat: item.lat,
            lng: item.lng,
            budget: item.budget,
            status: newStatus,
            createdAt: item.createdAt,
            validFrom: item.validFrom,
            validTo: item.validTo,
          );
        }
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
              ? const Center(child: Text("暂无记录"))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildItemCard(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    String title = "";
    String status = "";
    String date = "";
    Widget icon = const Icon(Icons.error);
    VoidCallback onTap = () {};

    if (item is Task) {
      title = item.title;
      status = item.status;
      date = item.createdAt;
      icon = const Icon(Icons.lightbulb_outline, color: Colors.blue);
      onTap = () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: item)),
        );
        // 监听返回值：如果详情页返回 true，说明执行了取消操作
        if (result == true) {
          _handleItemChange(item.id, 'canceled');
        }
      };
    } else if (item is Supply) {
      title = item.title;
      status = item.status;
      date = item.createdAt;
      icon = const Icon(Icons.camera_roll_outlined, color: Colors.orange);
      onTap = () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SupplyDetailScreen(supply: item)),
        );
        if (result == true) {
          _handleItemChange(item.id, 'canceled');
        }
      };
    }

    try {
       if (!date.endsWith('Z')) date += 'Z';
       final dt = DateTime.parse(date).toLocal();
       date = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: icon,
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(date),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status == 'canceled' ? Colors.grey[200] : (status == 'created' ? Colors.green[50] : Colors.orange[50]),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: status == 'canceled' ? Colors.grey : (status == 'created' ? Colors.green : Colors.orange),
            ),
          ),
        ),
      ),
    );
  }
}