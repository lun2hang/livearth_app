import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/task.dart';
import 'main.dart'; // 导入 MockAPI

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _isOwner = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    const storage = FlutterSecureStorage();
    final currentUserId = await storage.read(key: 'user_id');
    if (mounted && currentUserId != null) {
      setState(() {
        _isOwner = currentUserId == widget.task.userId;
      });
    }
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
            Text('取消后无法恢复，您确定要取消这个需求吗？', textAlign: TextAlign.center),
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
    final success = await MockAPI.cancelEntry(widget.task.id, 'task');
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取消成功')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取消失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('需求详情'),
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
            // 标题卡片
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
                  Text(
                    widget.task.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "¥${widget.task.budget}",
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        widget.task.status,
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        "ID: ${widget.task.id}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 描述信息
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
                  const Text("需求描述", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    widget.task.description?.isNotEmpty == true ? widget.task.description! : "暂无描述",
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 其他信息 (时间、地点)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.access_time, "发布时间", _formatTime(widget.task.createdAt)),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.timer_outlined, "有效期", "${_formatTime(widget.task.validFrom)}\n至 ${_formatTime(widget.task.validTo)}"),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.location_on_outlined, "地点坐标", "${widget.task.lat.toStringAsFixed(4)}, ${widget.task.lng.toStringAsFixed(4)}"),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isOwner
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildProviderButton(),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isOwner ? _buildOwnerFab() : null,
    );
  }

  Widget? _buildOwnerFab() {
    if (['created', 'matched'].contains(widget.task.status)) {
      return SizedBox(
        width: MediaQuery.of(context).size.width / 3,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleCancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.black87,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('取消需求', style: TextStyle(fontSize: 16)),
        ),
      );
    }
    return null;
  }

  Widget _buildProviderButton() {
    return ElevatedButton(
      onPressed: () async {
        final success = await MockAPI.acceptTask(widget.task.id);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('接单成功！')));
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('接单失败，请重试')));
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('立即接单', style: TextStyle(fontSize: 16)),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
          textAlign: TextAlign.right,
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
