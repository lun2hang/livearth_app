import 'package:flutter/material.dart';
import 'date_time_picker.dart'; // 导入时间选择器

class PublishTaskScreen extends StatefulWidget {
  const PublishTaskScreen({super.key});

  @override
  State<PublishTaskScreen> createState() => _PublishTaskScreenState();
}

class _PublishTaskScreenState extends State<PublishTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  // 0: 5分钟有效 (默认), 1: 设置有效时间
  int _selectedDurationType = 0;
  
  // 时间状态管理
  DateTime _startTime = DateTime.now();
  late DateTime _endTime = _startTime.add(const Duration(minutes: 5));

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _handlePublish() {
    // [需求 5] 点击发布需求后，模拟上传数据并返回
    print("UI交互: 点击发布需求");
    print("标题: ${_titleController.text}");
    print("POI: (未选择)");
    if (_selectedDurationType == 0) {
      print("时效: 5分钟有效");
    } else {
      print("时效: 自定义时间 ($_startTime 至 $_endTime)");
    }
    print("正文: ${_bodyController.text}");

    // 返回首页
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布需求'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.white, // 内容社区通常背景是白色
      // [需求 4] 点击空白处收起键盘，以便预览页面和点击底部按钮
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // [需求 1] 顶部输入title，输入框高度是1行
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '填写标题',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const Divider(),

              // [需求 2] POI 选择 (目前仅留UI，点击print)
              InkWell(
                onTap: () {
                  print("UI交互: 点击选择POI (未来接入Google Maps)");
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      const Text(
                        "添加地点",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const Divider(),

              // [需求 3] 2个互斥的选项，默认选中5分钟有效
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Text("有效时间：", style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    _buildDurationOption(0, "5分钟内有效"),
                    const SizedBox(width: 12),
                    _buildDurationOption(1, "预约未来时间"),
                  ],
                ),
              ),
              
              // [需求 1 & 2] 如果选中"设置有效时间"，显示开始和结束时间选择器
              if (_selectedDurationType == 1) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTimeBox("开始", _startTime, (newTime) {
                      setState(() {
                        _startTime = newTime;
                        // 保证结束时间至少比开始时间晚5分钟
                        final minEndTime = _startTime.add(const Duration(minutes: 5));
                        if (_endTime.isBefore(minEndTime)) {
                          _endTime = minEndTime;
                        }
                      });
                    }, minimumDate: DateTime.now()),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                    ),
                    _buildTimeBox("结束", _endTime, (newTime) {
                      setState(() {
                        _endTime = newTime;
                      });
                    }, minimumDate: _startTime.add(const Duration(minutes: 5))),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              const Divider(),

              // [需求 4] 正文输入区，输入框高度是5行
              TextField(
                controller: _bodyController,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: '添加更多描述...',
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ),
      // 底部固定按钮区域
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _handlePublish,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('发布需求', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }

  // 辅助方法：构建互斥选项按钮
  Widget _buildDurationOption(int value, String label) {
    final isSelected = _selectedDurationType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDurationType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.black54,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // 辅助方法：构建时间显示框
  Widget _buildTimeBox(String label, DateTime time, Function(DateTime) onTimeChanged, {DateTime? minimumDate}) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          // 确保 initialDateTime 不早于 minimumDate，防止崩溃
          DateTime initial = time;
          if (minimumDate != null && initial.isBefore(minimumDate!)) {
            initial = minimumDate!;
          }

          // 调用新的时间选择器
          final picked = await showDateTimePicker(
            context: context,
            initialDateTime: initial,
            minimumDate: minimumDate,
          );
          if (picked != null) {
            onTimeChanged(picked);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                "${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}