import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Dio singleton dengan Bearer token + auto-refresh saat 401.
class DioClient {
  DioClient._();

  static Dio? _instance;

  /// Dipanggil saat refresh token gagal (sesi habis) — di-set oleh auth provider.
  static void Function()? onSessionExpired;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // validateStatus default (null) sudah benar: 200-299 = sukses.
      // JANGAN override jadi `(status) => true` — itu memaksa kita membuat
      // konversi manual non-2xx -> DioException sendiri, yang berisiko bug
      // (pernah menghasilkan DioException [bad response]: null tanpa info
      // status code/body asli, karena Dio.badResponse() bawaan yang benar
      // justru tidak pernah terpakai).
    ));

    const publicPaths = [
      ApiConstants.login,
      ApiConstants.refresh,
      ApiConstants.forgotPassword,
      ApiConstants.resetPassword,
    ];

    // TODO(debug): hapus setelah masalah 403 login selesai didiagnosis.
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('[DIO] ${options.method} ${options.baseUrl}${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('[DIO] Response: ${response.statusCode} ${response.data}');
        return handler.next(response);
      },
      onError: (error, handler) {
        print('[DIO] Error: ${error.response?.statusCode} ${error.response?.data ?? error.message}');
        return handler.next(error);
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final isPublic = publicPaths.any((path) => options.path.contains(path));
        if (!isPublic) {
          final token = await SecureStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final alreadyRetried = error.requestOptions.extra['retried'] == true;
        final isRefreshCall = error.requestOptions.path.contains(ApiConstants.refresh);
        if (error.response?.statusCode == 401 && !alreadyRetried && !isRefreshCall) {
          try {
            final refreshToken = await SecureStorage.getRefreshToken();
            if (refreshToken == null) {
              await SecureStorage.clear();
              onSessionExpired?.call();
              return handler.reject(error);
            }

            final response = await Dio().post(
              '${ApiConstants.baseUrl}${ApiConstants.refresh}',
              data: {'refreshToken': refreshToken},
            );

            final newAccess = response.data['data']['accessToken'] as String;
            final newRefresh = response.data['data']['refreshToken'] as String;
            await SecureStorage.saveTokens(newAccess, newRefresh);

            error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
            error.requestOptions.extra['retried'] = true;
            final retryResponse = await dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } catch (_) {
            await SecureStorage.clear();
            onSessionExpired?.call();
            return handler.reject(error);
          }
        }
        return handler.next(error);
      },
    ));

    return dio;
  }
}
