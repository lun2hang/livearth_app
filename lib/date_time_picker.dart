import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 显示底部时间选择器 (iOS 风格滚轮)
/// 返回用户选择的 DateTime，如果取消则返回 null
Future<DateTime?> showDateTimePicker({
  required BuildContext context,
  required DateTime initialDateTime,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) async {
  DateTime tempPickedDate = initialDateTime;

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.white,
    builder: (BuildContext builder) {
      return Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            // 顶部操作栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CupertinoButton(
                  child: const Text('确定', style: TextStyle(color: Colors.blue)),
                  onPressed: () => Navigator.of(context).pop(tempPickedDate),
                ),
              ],
            ),
            const Divider(height: 0),
            // 时间选择器
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime, // 日期+时间
                initialDateTime: initialDateTime,
                minimumDate: minimumDate,
                maximumDate: maximumDate,
                use24hFormat: true,
                onDateTimeChanged: (DateTime newDateTime) {
                  tempPickedDate = newDateTime;
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}