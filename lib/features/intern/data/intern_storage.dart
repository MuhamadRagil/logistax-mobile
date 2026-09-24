import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan sesi intern di secure storage yang SAMA dengan HR, dengan key
/// berprefix `intern_`.
///
/// Sengaja tidak memakai instance dengan `sharedPreferencesName` sendiri:
/// plugin Android memakai satu objek native untuk semua instance dan tidak
/// pernah mengembalikan nama file ke default, sehingga setelah storage intern
/// dipakai, baca/tulis token HR akan ikut diarahkan ke file intern. Opsi di
/// sini harus identik dengan `SecureStorage` HR.
///
/// Isolasi dijamin oleh `SecureStorage.clear()` (HR) yang hanya menghapus key
/// miliknya, dan [clear] di sini yang hanya menghapus key intern.
class InternStorage {
  InternStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'intern_token';
  static const _profileKey = 'intern_profile';

  static Future<void> saveSession(String token, String profileJson) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _profileKey, value: profileJson);
  }

  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<String?> getProfile() => _storage.read(key: _profileKey);

  static Future<bool> hasSession() async => (await getToken()) != null;

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _profileKey);
  }
}
