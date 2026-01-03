import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart'; // 导入新的登录页面
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 用户中心页面 (未登录状态)
class ProfileScreen extends StatefulWidget {
  final GoogleSignInAccount? user;

  const ProfileScreen({super.key, this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 统一的用户信息状态
  String? _username;
  String? _email;
  String? _avatarUrl;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 判断是否登录
  bool get _isLoggedIn => _username != null || _email != null;

  @override
  void initState() {
    super.initState();
    _initUserState();
  }

  Future<void> _initUserState() async {
    // 1. 优先检查构造函数传入的 Google 用户 (通常为 null)
    if (widget.user != null) {
      _updateGoogleUser(widget.user!);
      return;
    }

    // 2. 检查本地安全存储 (Livearth 登录)
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      final username = await _storage.read(key: 'username');
      final email = await _storage.read(key: 'email');
      final avatar = await _storage.read(key: 'avatar');
      
      if (mounted) {
        setState(() {
          _username = username;
          _email = email;
          _avatarUrl = avatar;
        });
      }
      return;
    }

    // 3. 尝试 Google 静默登录
    _googleSignIn.signInSilently().then((user) {
      if (mounted && user != null) {
        _updateGoogleUser(user);
      }
    });
  }

  void _updateGoogleUser(GoogleSignInAccount user) {
    setState(() {
      _username = user.displayName;
      _email = user.email;
      _avatarUrl = user.photoUrl;
    });
  }

  Future<void> _handleSignOut() async {
    // 清除本地存储
    await _storage.deleteAll();
    // 断开 Google 连接
    await _googleSignIn.disconnect();
    
    setState(() {
      _username = null;
      _email = null;
      _avatarUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 顶部导航栏
      appBar: AppBar(
        title: const Text('用户中心'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white, // 防止滚动时变色
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // [区域 1] 顶部 1/3: 登录按钮
          Expanded(
            flex: 1,
            child: Center(
              child: _isLoggedIn
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_avatarUrl != null)
                          CircleAvatar(
                            backgroundImage:
                                NetworkImage(_avatarUrl!),
                            radius: 40,
                          )
                        else
                          const CircleAvatar(
                            radius: 40,
                            child: Icon(Icons.person, size: 40, color: Colors.grey),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          _username ?? '无昵称',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _email ?? '',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _handleSignOut,
                          child: const Text('退出登录'),
                        ),
                      ],
                    )
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                  
                  // 处理登录返回结果
                  if (result != null) {
                    if (result is GoogleSignInAccount) {
                      _updateGoogleUser(result);
                    } else if (result is Map) {
                      // Livearth 登录返回的 Map 数据
                      setState(() {
                        _username = result['username'];
                        _email = result['email'];
                        _avatarUrl = result['avatar'];
                      });
                    }
                  }
                },
                child: const Text('登录 / 注册'),
              ),
            ),
          ),

          // [区域 2] 中部 1/3: 2x2 功能入口
          Expanded(
            flex: 1,
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 2.8, // 调整宽高比，使按钮不那么高
              physics: const NeverScrollableScrollPhysics(), // 禁止网格滚动
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildGridItem(context, Icons.camera_roll_outlined, '我发布的供给'),
                _buildGridItem(context, Icons.lightbulb_outline, '我发布的需求'),
                _buildGridItem(context, Icons.receipt_long_outlined, '我的历史订单'),
                _buildGridItem(context, Icons.bar_chart_outlined, '历史统计数据'),
              ],
            ),
          ),

          // [区域 3] 底部 1/3: 文字区域
          const Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'See the Livearth',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建网格按钮的辅助方法
  Widget _buildGridItem(BuildContext context, IconData icon, String label) {
    return InkWell(
      onTap: () {
        print("UI交互: 点击 '$label'");
        // 后续实现真实跳转逻辑
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey[700]),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
