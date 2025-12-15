import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'tiktok_auth_screen.dart';

/// 登录和注册页面
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录 / 注册'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // [区域 1] 上半部分: 第三方登录
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSocialLoginButton(
                    text: '使用 Livearth 登录',
                    icon: Icons.public, // “小地球”图标
                    onPressed: () => print("UI交互: 点击 Livearth 登录"),
                    backgroundColor: Colors.blue, // 使用应用主题色
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 24), // 增大与第三方登录的间距

                  _buildSocialLoginButton(
                    text: '使用 Apple 登录',
                    icon: Icons.apple,
                    onPressed: () => print("UI交互: 点击 Apple 登录"),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  _buildSocialLoginButton(
                    text: '使用 Google 登录',
                    // 使用自定义的 Widget 作为图标
                    iconWidget: const Text('G', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54)),
                    onPressed: () async {
                      try {
                        final GoogleSignIn googleSignIn = GoogleSignIn();
                        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

                        if (googleUser != null) {
                          print("流程: Google 登录成功！");
                          print("用户名: ${googleUser.displayName}");
                          print("邮箱: ${googleUser.email}");
                          // 在这里，您可以获取认证信息并发送到您的后端服务器
                        } else {
                          print("流程: 用户取消了 Google 登录");
                        }
                      } catch (error) {
                        print("流程: Google 登录出错: $error");
                      }
                    },
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    isOutlined: true,
                    // 因为 iconWidget 已经定义了颜色，所以这里不再需要 icon
                    // icon: Icons.g_mobiledata,
                  ),
                  const SizedBox(height: 16),
                  _buildSocialLoginButton(
                    text: '使用 Facebook 登录',
                    icon: Icons.facebook,
                    onPressed: () => print("UI交互: 点击 Facebook 登录"),
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  _buildSocialLoginButton(
                    text: '使用 TikTok 登录',
                    icon: Icons.music_note,
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const TikTokAuthScreen()),
                      );

                      if (result == true) {
                        print("流程: TikTok 登录成功！准备跳转到主页...");
                        // 在这里可以执行登录成功后的逻辑，例如关闭登录流程回到主页
                      }
                    },
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // [区域 2] 下半部分: 注册按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
            child: OutlinedButton(
              onPressed: () {
                print("UI交互: 点击注册按钮");
                // 后续实现注册逻辑 (例如跳转到手机/邮箱注册页面)
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: Colors.black87, // 深黑色文字
                side: BorderSide(color: Colors.grey.shade400), // 按钮轮廓
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '还没有账号？点击注册',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建社交登录按钮的辅助方法
  Widget _buildSocialLoginButton({
    required String text,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
    IconData? icon,
    Widget? iconWidget,
    bool isOutlined = false,
  }) {
    return ElevatedButton.icon(
      // 优先使用 iconWidget，如果为 null，则使用 icon
      icon: iconWidget ?? Icon(icon, color: foregroundColor),
      label: Text(text),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isOutlined
              ? BorderSide(color: Colors.grey.shade300)
              : BorderSide.none,
        ),
        elevation: isOutlined ? 0 : 2,
      ),
    );
  }
}
