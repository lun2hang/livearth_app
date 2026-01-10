import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late Dio dio;

  factory DioClient() {
    return _instance;
  }

  DioClient._internal() {
    // 假设 FastAPI 运行在 8080 端口
    // Android 模拟器请将 IP 改为 '10.0.2.2'
    const String baseUrl = 'http://127.0.0.1:8080';

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加认证拦截器：自动在请求头中携带 Token
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          const storage = FlutterSecureStorage();
          final token = await storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            print("🔐 [Dio] Token 已添加到请求头: ${token.substring(0, 6)}...");
          } else {
            print("⚠️ [Dio] 未发现 Token，请求将不带身份信息发送");
          }
        } catch (e) {
          print("❌ [Dio] 读取 Token 异常: $e");
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // 全局处理 401 未授权 (Token 过期)
        if (e.response?.statusCode == 401) {
          print("🔒 [Dio] Token 已失效 (401)，正在清除本地登录信息");
          const storage = FlutterSecureStorage();
          await storage.deleteAll();
        }
        return handler.next(e);
      },
    ));

    // 添加日志拦截器，方便调试
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// 检查 Token 有效性
  /// 如果 Token 存在但已过期，拦截器会捕获 401 并清除存储
  Future<void> checkTokenValidity() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    // 如果本地没有 Token，直接返回，视为未登录
    if (token == null) return;

    try {
      // 调用一个受保护的接口来验证 Token。
      // 即使不需要返回值，只要状态码是 200 即代表 Token 有效。
      await dio.get('/users/me');
    } catch (e) {
      // 忽略错误，如果是 401，拦截器已经处理了清除逻辑
    }
  }
}