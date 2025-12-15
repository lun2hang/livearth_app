import 'package:flutter/material.dart';

/// 模拟TikTok第三方授权的页面
class TikTokAuthScreen extends StatelessWidget {
  const TikTokAuthScreen({super.key});

  // 模拟点击“授权”按钮的操作
  void _onAuthorize(BuildContext context) {
    print("UI交互: 用户在TikTok模拟页面点击了 '授权'");
    // 导航回上一页，并传递一个 true 值表示成功
    Navigator.pop(context, true);
  }

  // 模拟点击“取消”按钮的操作
  void _onCancel(BuildContext context) {
    print("UI交互: 用户在TikTok模拟页面点击了 '取消'");
    // 直接导航回上一页，不传递值
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 真实的WebView授权页通常没有标题或只有一个关闭按钮
        title: const Text(''),
        backgroundColor: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // 顶部Logo和标题
            const Icon(Icons.music_note, size: 48, color: Colors.black),
            const SizedBox(height: 16),
            const Text(
              'Livearth 想要访问你的 TikTok 账号',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '这会将你的 TikTok 账号与 Livearth 连接。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            // 权限列表
            const Text(
              '此应用将能够：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('访问你的公开信息'),
              dense: true,
            ),
            const Spacer(), // 将按钮推到底部
            // 底部操作按钮
            ElevatedButton(
              onPressed: () => _onAuthorize(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55), // TikTok 风格的红色
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('授权', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _onCancel(context),
              child: Text(
                '取消',
                style: TextStyle(color: Colors.grey[700], fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
