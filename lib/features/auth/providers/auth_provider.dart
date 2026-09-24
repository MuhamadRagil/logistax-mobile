import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_model.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Sumber kebenaran status login. ChangeNotifier agar bisa jadi
/// refreshListenable GoRouter sekaligus provider Riverpod.
class AuthController extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  AuthController() {
    DioClient.onSessionExpired = sessionExpired;
  }

  String? get employeeId => user?.employee?.id;
  bool get isSpv => user?.role == 'spv';
  bool get canSeeTeam =>
      user?.role == 'spv' || user?.role == 'hrd' || user?.role == 'super_admin';

  /// Dipanggil splash: cek token tersimpan → validasi ke server.
  Future<void> init() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 1400));
    try {
      final token = await SecureStorage.getAccessToken();
      if (token == null) {
        await minDelay;
        status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }
      // Interceptor akan otomatis coba refresh saat 401.
      final me = await _repo.me();
      user = me;
      await SecureStorage.saveUser(me.encode());
      await minDelay;
      status = AuthStatus.authenticated;
      notifyListeners();
    } catch (_) {
      try {
        await SecureStorage.clear();
      } catch (_) {
        // storage gagal dibersihkan — tetap lanjut anggap sesi tidak valid
      }
      await minDelay;
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Melempar [ApiException] — pemanggil (UI) wajib menangkapnya untuk
  /// menampilkan pesan error, bukan membiarkan exception mentah lolos.
  Future<void> login(String email, String password) async {
    try {
      final result = await _repo.login(email, password);
      await SecureStorage.saveTokens(result.accessToken, result.refreshToken);
      await SecureStorage.saveUser(result.user.encode());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_email', email);
      user = result.user;
      status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Login biometrik: token masih tersimpan → cukup validasi /users/me.
  /// Return false jika sesi sudah tidak valid (harus login manual).
  Future<bool> resumeSession() async {
    try {
      final token = await SecureStorage.getAccessToken();
      if (token == null) return false;
      final me = await _repo.me();
      user = me;
      await SecureStorage.saveUser(me.encode());
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final me = await _repo.me();
      user = me;
      await SecureStorage.saveUser(me.encode());
      notifyListeners();
    } catch (_) {
      // biarkan data lama
    }
  }

  Future<void> logout() async {
    final refresh = await SecureStorage.getRefreshToken();
    await _repo.logoutServer(refresh);
    await SecureStorage.clear();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Dipakai HANYA oleh alur intern: saat splash memulihkan sesi intern, cek
  /// sesi HR dilewati. Status ditandai unauthenticated agar setelah logout
  /// intern pengguna diarahkan ke layar login — bukan otomatis masuk ke akun
  /// karyawan yang mungkin tersimpan di perangkat yang sama. Token HR tetap
  /// tersimpan dan dipulihkan normal saat app dibuka berikutnya.
  void skipSessionCheck() {
    if (status == AuthStatus.unknown) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  void sessionExpired() {
    if (status == AuthStatus.authenticated) {
      user = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }
}

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) => AuthController());

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
