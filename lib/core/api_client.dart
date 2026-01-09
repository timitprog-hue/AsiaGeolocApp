import 'package:dio/dio.dart';
import 'auth_storage.dart';

class ApiClient {
  static const String BASE_URL = 'http://192.168.107.53:8000/api'; // <-- GANTI

  final Dio dio;
  final AuthStorage storage;

  ApiClient(this.storage)
      : dio = Dio(BaseOptions(
          baseUrl: BASE_URL,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Accept'] = 'application/json';
        return handler.next(options);
      },
    ));
  }
}
