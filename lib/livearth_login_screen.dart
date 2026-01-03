import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'api/dio_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LivearthLoginScreen extends StatefulWidget {
  const LivearthLoginScreen({super.key});

  @override
  State<LivearthLoginScreen> createState() => _LivearthLoginScreenState();
}

class _LivearthLoginScreenState extends State<LivearthLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dio = DioClient().dio;
      // FastAPI 的 OAuth2PasswordRequestForm 默认接收 form-urlencoded 数据
      final response = await dio.post(
        '/token',
        data: {
          'username': _usernameController.text, // 后端接收 username 字段，支持用户名或邮箱
          'password': _passwordController.text,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = response.data as Map<String, dynamic>;

      // 将返回的数据全部放入安全存储
      const storage = FlutterSecureStorage();
      await storage.write(key: 'access_token', value: data['access_token']);
      await storage.write(key: 'token_type', value: data['token_type']);
      await storage.write(key: 'user_id', value: data['user_id']);
      await storage.write(key: 'username', value: data['username']);
      await storage.write(key: 'email', value: data['email']);
      // 头像可能为空，做个判断
      if (data['avatar'] != null) {
        await storage.write(key: 'avatar', value: data['avatar']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
        );
        // 返回登录结果
        Navigator.pop(context, data);
      }
    } catch (e) {
      String errorMsg = "登录失败，请稍后重试";
      if (e is DioException && e.response != null) {
        // 解析 FastAPI 返回的错误详情
        final detail = e.response?.data['detail'];
        if (detail != null) {
          errorMsg = detail.toString();
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Livearth 登录'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.lock_person, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                
                // 用户名/邮箱输入框
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名 / 邮箱',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? '请输入用户名或邮箱' : null,
                ),
                const SizedBox(height: 16),
                
                // 密码输入框
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '密码',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? '请输入密码' : null,
                ),
                const SizedBox(height: 32),
                
                // 登录按钮
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('登录', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}