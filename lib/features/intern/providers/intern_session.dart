import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/session_prefs.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/intern_api_client.dart';
import '../data/intern_repository.dart';
import '../data/intern_storage.dart';
import '../intern_config.dart';
import '../models/intern_models.dart';

/// Status sesi intern — terpisah total dari `AuthController` (HR).
/// Router mendengarkan keduanya; bila sesi intern aktif, hanya rute
/// `/intern/*` yang boleh diakses.
class InternSessionController extends ChangeNotifier {
  InternSessionController() {
    InternApiClient.onUnauthorized = _expire;
  }

  final _repo = InternRepository();

  InternProfile? profile;

  bool get isActive => profile != null;

  /// Splash: pulihkan sesi intern duluan bila perlu. Aturannya: hanya bila
  /// token intern tersimpan DAN (sesi terakhir yang login adalah intern ATAU
  /// tidak ada token HR sama sekali). Tanpa token intern → selalu false,
  /// sehingga alur karyawan identik dengan sebelum fitur magang ada.
  Future<bool> shouldRestoreFirst() async {
    if (!InternConfig.isConfigured) return false;
    if (!await InternStorage.hasSession()) return false;
    if (await SessionPrefs.lastActive() == SessionKind.intern) return true;
    return await SecureStorage.getAccessToken() == null;
  }

  /// Muat sesi intern tersimpan. Tidak ada endpoint profil di backend magang,
  /// jadi token baru divalidasi saat request pertama (401 → [_expire]).
  Future<bool> restore() async {
    if (!InternConfig.isConfigured) return false;
    final token = await InternStorage.getToken();
    final stored = InternProfile.decode(await InternStorage.getProfile());
    if (token == null || stored == null) {
      await InternStorage.clear();
      return false;
    }
    profile = stored;
    notifyListeners();
    return true;
  }

  Future<void> login(String email, String password) async {
    final result = await _repo.login(email, password);
    await InternStorage.saveSession(result.token, result.profile.encode());
    await SessionPrefs.setLastActive(SessionKind.intern);
    profile = result.profile;
    notifyListeners();
  }

  /// Logout HANYA sesi intern — token karyawan (bila ada) tidak disentuh.
  Future<void> logout() async {
    await _repo.logout();
    await InternStorage.clear();
    profile = null;
    notifyListeners();
  }

  Future<void> _expire() async {
    if (!isActive) return;
    await InternStorage.clear();
    profile = null;
    notifyListeners();
  }
}

final internSessionProvider =
    ChangeNotifierProvider<InternSessionController>((ref) => InternSessionController());
