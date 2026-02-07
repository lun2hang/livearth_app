import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import 'login_screen.dart'; // 导入新的登录页面
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api/dio_client.dart';
import 'history_screen.dart'; // 导入历史记录页面
import 'main.dart'; // 导入 MockAPI
import 'order_list_screen.dart'; // 导入订单列表页面
import 'chat_screen.dart'; // 导入 RtmManager

/// 用户中心页面 (未登录状态)
class ProfileScreen extends StatefulWidget {
  final GoogleSignInAccount? user;

  const ProfileScreen({super.key, this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 统一的用户信息状态
  String? _userId;
  String? _username;
  String? _email;
  String? _avatarUrl;
  String? _location;
  
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
      await _authenticateWithGoogle(widget.user!);
      return;
    }

    // 2. 检查本地安全存储 (Livearth 登录)
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      final userId = await _storage.read(key: 'user_id');
      final username = await _storage.read(key: 'username');
      final email = await _storage.read(key: 'email');
      final avatar = await _storage.read(key: 'avatar');
      final location = await _storage.read(key: 'location');
      
      if (mounted) {
        setState(() {
          _userId = userId;
          _username = username;
          _email = email;
          _avatarUrl = avatar;
          _location = location;
        });
      }
      return;
    }

    // 3. 尝试 Google 静默登录
    _googleSignIn.signInSilently().then((user) {
      if (mounted && user != null) {
        _authenticateWithGoogle(user);
      } else {
        // 4. 尝试 Facebook 静默登录 (如果 Google 未登录)
        FacebookAuth.instance.accessToken.then((accessToken) {
          if (mounted && accessToken != null) _authenticateWithFacebook(accessToken);
        });
      }
    });
  }

  // 核心修改：实现五层模型，用 Google Token 换取系统 JWT
  Future<void> _authenticateWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      // [第一层] Flutter 层: 获取 Google ID Token
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("无法获取 Google ID Token");
      }

      // [第二层] 验证层: 调用后端验证接口
      final dio = DioClient().dio;
      final response = await dio.post('/auth/social-login', data: {
        'provider': 'google',
        'token': idToken,
      });

      // [第四层] 发放层: 获取并存储系统 JWT
      final accessToken = response.data['access_token'];
      await _storage.write(key: 'access_token', value: accessToken);

      // [第五层] 业务层: 更新本地状态
      // 直接使用 Google 的信息进行显示，无需调用 /users/me
      final username = googleUser.displayName;
      final email = googleUser.email;
      final avatar = googleUser.photoUrl;

      final systemUserId = response.data['user_id'];

      // 持久化与更新 UI
      await _storage.write(key: 'user_id', value: systemUserId);
      if (username != null) await _storage.write(key: 'username', value: username);
      await _storage.write(key: 'email', value: email);
      if (avatar != null) await _storage.write(key: 'avatar', value: avatar);

      if (mounted) {
        setState(() {
          _userId = systemUserId;
          _username = username;
          _email = email;
          _avatarUrl = avatar;
        });
      }
    } catch (e) {
      print("Google 登录后端验证失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("登录失败: $e")),
        );
      }
      // 验证失败，断开 Google 连接以允许重试
      await _googleSignIn.disconnect();
    }
  }

  // 新增：Facebook 登录逻辑 (参考 Google 逻辑)
  Future<void> _authenticateWithFacebook(AccessToken accessToken) async {
    try {
      // [第二层] 验证层: 调用后端验证接口
      final dio = DioClient().dio;
      final response = await dio.post('/auth/social-login', data: {
        'provider': 'facebook',
        'token': accessToken.token,
      });

      // [第四层] 发放层: 获取并存储系统 JWT
      final jwt = response.data['access_token'];
      await _storage.write(key: 'access_token', value: jwt);

      // [第五层] 业务层: 获取 Facebook 用户信息
      final userData = await FacebookAuth.instance.getUserData();
      
      final username = userData['name'];
      final email = userData['email'];
      final avatar = userData['picture']?['data']?['url'];

      final systemUserId = response.data['user_id'];

      // 持久化与更新 UI
      await _storage.write(key: 'user_id', value: systemUserId);
      if (username != null) await _storage.write(key: 'username', value: username);
      if (email != null) await _storage.write(key: 'email', value: email);
      if (avatar != null) await _storage.write(key: 'avatar', value: avatar);

      if (mounted) {
        setState(() {
          _userId = systemUserId;
          _username = username;
          _email = email;
          _avatarUrl = avatar;
        });
      }
    } catch (e) {
      print("Facebook 登录后端验证失败: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("登录失败: $e")));
      await FacebookAuth.instance.logOut();
    }
  }

  // 新增：Apple 登录逻辑
  Future<void> _authenticateWithApple(AuthorizationCredentialAppleID credential) async {
    try {
      // [第二层] 验证层: 调用后端验证接口
      final dio = DioClient().dio;
      final response = await dio.post('/auth/social-login', data: {
        'provider': 'apple',
        'token': credential.identityToken, // Apple 的 JWT
      });

      // [第四层] 发放层: 获取并存储系统 JWT
      final accessToken = response.data['access_token'];
      await _storage.write(key: 'access_token', value: accessToken);

      // [第五层] 业务层: 更新本地状态
      // 注意：Apple 仅在首次登录返回 email 和 name，后续为 null
      final email = credential.email;
      final familyName = credential.familyName;
      final givenName = credential.givenName;
      String? username;
      if (familyName != null || givenName != null) {
        username = "${familyName ?? ''}${givenName ?? ''}";
      }

      final systemUserId = response.data['user_id'];

      await _storage.write(key: 'user_id', value: systemUserId);
      if (username != null) await _storage.write(key: 'username', value: username);
      if (email != null) await _storage.write(key: 'email', value: email);

      if (mounted) {
        setState(() {
          _userId = systemUserId;
          if (username != null) _username = username;
          if (email != null) _email = email;
        });
      }
    } catch (e) {
      print("Apple 登录后端验证失败: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("登录失败: $e")));
    }
  }

  Future<void> _handleSignOut() async {
    // 清除本地存储
    await _storage.deleteAll();
    // 断开连接
    await _googleSignIn.disconnect();
    await FacebookAuth.instance.logOut();
    
    setState(() {
      _userId = null;
      _username = null;
      _email = null;
      _avatarUrl = null;
      _location = null;
    });
  }

  // 处理功能按钮点击
  Future<void> _handleGridItemTap(String title, Future<List<dynamic>> Function() fetcher) async {
    // 1. 如果未登录，跳转登录页面
    if (!_isLoggedIn) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      
      // 处理登录返回结果
      if (result != null) {
        if (result is GoogleSignInAccount) {
          await _authenticateWithGoogle(result);
        } else if (result is AccessToken) {
          await _authenticateWithFacebook(result);
        } else if (result is AuthorizationCredentialAppleID) {
          await _authenticateWithApple(result);
        } else if (result is Map) {
          setState(() {
            _userId = result['user_id'];
            _username = result['username'];
            _email = result['email'];
            _avatarUrl = result['avatar'];
          });
        }
      } else {
        return; // 用户取消登录，不进行跳转
      }
    }

    // 2. 已登录，跳转到历史页面
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryScreen(title: title, onLoad: fetcher),
        ),
      );
    }
  }

  // 处理订单历史点击
  Future<void> _handleOrderHistoryTap() async {
    if (!_isLoggedIn) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      
      if (result != null) {
        if (result is GoogleSignInAccount) {
          await _authenticateWithGoogle(result);
        } else if (result is AccessToken) {
          await _authenticateWithFacebook(result);
        } else if (result is Map) {
          setState(() {
            _userId = result['user_id'];
            _username = result['username'];
            _email = result['email'];
            _avatarUrl = result['avatar'];
          });
        }
      } else {
        return;
      }
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OrderListScreen()),
      );
    }
  }

  // 获取当前定位
  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '请在系统设置中开启位置服务';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '位置权限被拒绝';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw '位置权限被永久拒绝，请前往设置开启';
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在定位...')));

      // 获取经纬度
      Position position = await Geolocator.getCurrentPosition();
      
      // 保存经纬度供 API 使用
      await _storage.write(key: 'latitude', value: position.latitude.toString());
      await _storage.write(key: 'longitude', value: position.longitude.toString());

      String locationText;
      try {
        // 尝试逆地理编码 (经纬度 -> 城市名)
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          
          final province = place.administrativeArea ?? '';
          final city = place.locality ?? '';
          final district = place.subLocality ?? '';

          // 拼接显示：省 + 市 + 区
          // 逻辑：如果城市名与省名相同（如直辖市），则不重复显示城市名
          List<String> parts = [];
          if (province.isNotEmpty) parts.add(province);
          if (city.isNotEmpty && city != province) parts.add(city);
          if (district.isNotEmpty) parts.add(district);
          
          locationText = parts.isNotEmpty ? parts.join(' ') : (place.country ?? "未知位置");
        } else {
          locationText = "未知位置";
        }
      } catch (e) {
        // 如果解析失败（常见于模拟器或网络不佳），兜底显示经纬度
        locationText = "${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}";
      }
      
      await _storage.write(key: 'location', value: locationText);
      if (mounted) setState(() => _location = locationText);
    } catch (e) {
      print("定位失败: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('定位失败: $e')));
    }
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
                      await _authenticateWithGoogle(result);
                    } else if (result is AccessToken) {
                      await _authenticateWithFacebook(result);
                    } else if (result is Map) {
                      // Livearth 登录返回的 Map 数据
                      setState(() {
                        _userId = result['user_id'];
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
                _buildGridItem(context, Icons.camera_roll_outlined, '我发布的供给', 
                  () => _handleGridItemTap('我发布的供给', MockAPI.fetchUserSupplies)),
                
                _buildGridItem(context, Icons.lightbulb_outline, '我发布的需求',
                  () => _handleGridItemTap('我发布的需求', MockAPI.fetchUserTasks)),
                
                _buildGridItem(context, Icons.receipt_long_outlined, '我的历史订单', 
                  _handleOrderHistoryTap, showBadge: true), // 开启红点显示
                
                _buildGridItem(context, Icons.bar_chart_outlined, '历史统计数据', 
                  () => print("UI交互: 点击 '历史统计数据'")),
              ],
            ),
          ),

          // [区域 3] 底部 1/3: 文字区域
          Expanded(
            flex: 1,
            child: Center(
              child: InkWell(
                onTap: _getLocation,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, color: Colors.grey[400], size: 28),
                      const SizedBox(height: 8),
                      Text(
                        _location ?? '点击获取当前位置',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建网格按钮的辅助方法
  Widget _buildGridItem(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool showBadge = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showBadge)
              ValueListenableBuilder<Map<String, int>>(
                valueListenable: RtmManager().unreadCountsNotifier,
                builder: (context, counts, child) {
                  final total = counts.values.fold(0, (sum, c) => sum + c);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, color: Colors.grey[700]),
                      if (total > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  );
                },
              )
            else
              Icon(icon, color: Colors.grey[700]),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
