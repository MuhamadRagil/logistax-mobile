import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/user_model.dart';

class LoginResult {
  final AppUser user;
  final String accessToken;
  final String refreshToken;

  const LoginResult({required this.user, required this.accessToken, required this.refreshToken});
}

class AuthRepository {
  final _dio = DioClient.instance;

  Future<LoginResult> login(String email, String password) async {
    try {
      final res = await _dio.post(ApiConstants.login, data: {'email': email, 'password': password});
      // TODO(debug): hapus setelah masalah login selesai didiagnosis.
      print('[AUTH] Response data: ${res.data}');
      print('[AUTH] Response type: ${res.data.runtimeType}');

      final body = res.data;
      if (body is! Map<String, dynamic> || body['data'] is! Map<String, dynamic>) {
        throw ApiException('Format respons login tidak sesuai (bukan JSON object)');
      }
      final data = body['data'] as Map<String, dynamic>;
      if (data['user'] is! Map<String, dynamic> ||
          data['accessToken'] is! String ||
          data['refreshToken'] is! String) {
        throw ApiException('Data login tidak lengkap dari server');
      }

      return LoginResult(
        user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    } catch (e) {
      print('[AUTH] Login error: $e');
      throw ApiException.fromDio(e);
    }
  }

  /// Validasi sesi + ambil profil terbaru.
  Future<AppUser> me() async {
    try {
      final res = await _dio.get(ApiConstants.me);
      return AppUser.fromJson(res.data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> logoutServer(String? refreshToken) async {
    try {
      await _dio.post(ApiConstants.logout,
          data: refreshToken != null ? {'refreshToken': refreshToken} : null);
    } catch (_) {
      // best-effort — sesi lokal tetap dihapus
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post(ApiConstants.forgotPassword, data: {'email': email});
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    try {
      await _dio.post(ApiConstants.resetPassword,
          data: {'token': token, 'newPassword': newPassword});
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _dio.post(ApiConstants.changePassword,
          data: {'currentPassword': currentPassword, 'newPassword': newPassword});
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
