import 'package:dio/dio.dart';

import '../intern_config.dart';
import 'intern_storage.dart';

/// Dio khusus backend magang. Tidak berbagi instance, interceptor, maupun
/// token dengan `DioClient` HR.
///
/// Token Sanctum tidak punya refresh token dan tidak kedaluwarsa; 401 berarti
/// token dicabut → sesi intern diakhiri lewat [onUnauthorized].
class InternApiClient {
  InternApiClient._();

  static Dio? _instance;

  /// Di-set oleh `InternSessionController`.
  static void Function()? onUnauthorized;

  static Dio get instance => _instance ??= _create();

  static Dio _create() {
    final dio = Dio(BaseOptions(
      baseUrl: InternConfig.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      // Tanpa Accept JSON, Laravel mengembalikan halaman HTML/redirect untuk
      // error validasi & auth alih-alih JSON { message }.
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.path != InternEndpoints.login) {
          final token = await InternStorage.getToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final path = error.requestOptions.path;
        if (error.response?.statusCode == 401 &&
            path != InternEndpoints.login &&
            path != InternEndpoints.logout) {
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));

    return dio;
  }
}
