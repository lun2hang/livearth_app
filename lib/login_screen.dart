import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'register_screen.dart'; // 导入注册页面
import 'livearth_login_screen.dart'; // 导入 Livearth 登录页面

/// 登录和注册页面
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
      body: _buildLoginView(),
    );
  }

  // 构建原来的登录页面
  Widget _buildLoginView() {
    return Column(
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
                    icon: Icons.email,
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LivearthLoginScreen()),
                      );
                      // 如果登录成功并返回了数据，继续向上返回给 ProfileScreen
                      if (result != null && context.mounted) {
                        Navigator.pop(context, result);
                      }
                    },
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  _buildSocialLoginButton(
                    text: '使用 Google 登录',
                    // 使用自定义的 Widget 作为图标
                    iconWidget: const Text('G', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54)),
                    onPressed: () async {
                      try {
                        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

                        if (googleUser != null) {
                          print("流程: Google 登录成功！");
                          print("用户名: ${googleUser.displayName}");
                          print("邮箱: ${googleUser.email}");
                          // 在这里，您可以获取认证信息并发送到您的后端服务器
                          if (mounted) {
                            Navigator.of(context).pop(googleUser);
                          }
                        } else {
                          print("流程: 用户取消了 Google 登录");
                        }
                      } catch (error) {
                        print("流程: Google 登录出错: $error");
                      }
                    },
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    isOutlined: true,
                    // 因为 iconWidget 已经定义了颜色，所以这里不再需要 icon
                    // icon: Icons.g_mobiledata,
                  ),
                  const SizedBox(height: 16),
                  _buildSocialLoginButton(
                    text: '使用 Facebook 登录',
                    icon: Icons.facebook,
                    onPressed: () async {
                      try {
                        final LoginResult result = await FacebookAuth.instance.login();
                        if (result.status == LoginStatus.success) {
                          print("流程: Facebook 登录成功！");
                          if (mounted) {
                            // 将 AccessToken 返回给 ProfileScreen
                            Navigator.of(context).pop(result.accessToken);
                          }
                        } else {
                          print("流程: Facebook 登录失败: ${result.message}");
                        }
                      } catch (e) {
                        print("流程: Facebook 登录出错: $e");
                      }
                    },
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  _buildSocialLoginButton(
                    text: '使用 Apple 登录',
                    icon: Icons.apple,
                    onPressed: () => print("UI交互: 点击 Apple 登录"),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40.0, right: 40.0, bottom: 40.0),
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('注册 Livearth 账户'),
            ),
          ),
        ],
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
