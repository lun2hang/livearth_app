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
    ));

    // 添加日志拦截器，方便调试
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }
}