import 'package:dio/dio.dart';

import '../constants/app_strings.dart';

/// Error API yang siap ditampilkan ke user.
/// Envelope error backend: { success: false, error: string, statusCode: int }
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  factory ApiException.fromDio(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return ApiException(data['error'] as String, statusCode: error.response?.statusCode);
      }
      if (data is Map && data['message'] is String) {
        return ApiException(data['message'] as String, statusCode: error.response?.statusCode);
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionError:
          return ApiException(AppStrings.errNetwork, statusCode: error.response?.statusCode);
        default:
          return ApiException(AppStrings.errGeneric, statusCode: error.response?.statusCode);
      }
    }
    return ApiException(AppStrings.errGeneric);
  }

  @override
  String toString() => message;
}
