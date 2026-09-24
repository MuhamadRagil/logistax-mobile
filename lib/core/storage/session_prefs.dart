import 'package:shared_preferences/shared_preferences.dart';

/// Jenis sesi login. Karyawan (HR) dan intern (magang) memakai backend,
/// token, dan storage yang terpisah; hanya satu yang aktif dalam satu waktu.
enum SessionKind { hr, intern }

/// Preferensi lintas-sesi yang disimpan di SharedPreferences — sengaja BUKAN
/// di secure storage, karena `SecureStorage.clear()` milik HR memanggil
/// `deleteAll()` dan akan ikut menghapusnya.
class SessionPrefs {
  SessionPrefs._();

  static const _lastActiveKey = 'last_active_session';
  static const _loginModeKey = 'login_mode';

  /// Sesi yang terakhir berhasil login — menentukan sesi mana yang dipulihkan
  /// lebih dulu di splash bila keduanya tersimpan di perangkat.
  static Future<SessionKind?> lastActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _parse(prefs.getString(_lastActiveKey));
    } catch (_) {
      return null;
    }
  }

  /// Tidak pernah melempar: dipanggil setelah login berhasil, dan kegagalan
  /// menulis preferensi tidak boleh menggagalkan login.
  static Future<void> setLastActive(SessionKind kind) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastActiveKey, kind.name);
    } catch (_) {}
  }

  /// Pilihan toggle terakhir di layar login (default: karyawan).
  static Future<SessionKind> loginMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _parse(prefs.getString(_loginModeKey)) ?? SessionKind.hr;
    } catch (_) {
      return SessionKind.hr;
    }
  }

  static Future<void> setLoginMode(SessionKind kind) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_loginModeKey, kind.name);
    } catch (_) {}
  }

  static SessionKind? _parse(String? raw) => switch (raw) {
        'hr' => SessionKind.hr,
        'intern' => SessionKind.intern,
        _ => null,
      };
}
