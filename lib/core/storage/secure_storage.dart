import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  static Future<String?> getAccessToken() => _storage.read(key: 'access_token');
  static Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

  static Future<void> saveUser(String userJson) => _storage.write(key: 'user', value: userJson);
  static Future<String?> getUser() => _storage.read(key: 'user');

  /// Hapus hanya key sesi HR — BUKAN `deleteAll()`, karena storage yang sama
  /// juga menyimpan sesi intern (`intern_*`) yang tidak boleh ikut terhapus.
  static Future<void> clear() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user');
  }
}
