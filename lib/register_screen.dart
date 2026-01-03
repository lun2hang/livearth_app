import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'api/dio_client.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // 控制器
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    // 监听输入变化以更新按钮状态
    _usernameController.addListener(_checkInput);
    _emailController.addListener(_checkInput);
    _passwordController.addListener(_checkInput);
  }

  void _checkInput() {
    final isValid = _usernameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;
    if (isValid != _isButtonEnabled) {
      setState(() {
        _isButtonEnabled = isValid;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dio = DioClient().dio;
      await dio.post(
        '/register',
        data: {
          'username': _usernameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，请登录')),
        );
        Navigator.pop(context); // 返回登录页
      }
    } catch (e) {
      String errorMsg = "注册失败: $e";
      if (e is DioException && e.response != null) {
        final detail = e.response?.data['detail'];
        errorMsg = detail ?? "注册失败";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
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
        title: const Text('注册账户'),
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
                const Text(
                  "创建 Livearth 账号",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // 用户名
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: "用户名",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),

                // 邮箱
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "邮箱",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // 密码
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "密码",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 32),

                // 注册按钮
                ElevatedButton(
                  onPressed: (_isButtonEnabled && !_isLoading) ? _handleRegister : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("注册", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}