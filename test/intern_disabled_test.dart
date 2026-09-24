// Build TANPA --dart-define=INTERN_API_URL (APK karyawan saat ini):
//   flutter test test/intern_disabled_test.dart
//
// Memastikan fitur magang benar-benar tidak aktif — layar login identik
// dengan versi karyawan saja, dan data intern yang (entah bagaimana)
// tersimpan di perangkat diabaikan.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logistax_mobile/core/storage/session_prefs.dart';
import 'package:logistax_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:logistax_mobile/features/intern/data/intern_storage.dart';
import 'package:logistax_mobile/features/intern/intern_config.dart';
import 'package:logistax_mobile/features/intern/models/intern_models.dart';
import 'package:logistax_mobile/features/intern/presentation/pages/intern_home_page.dart';
import 'package:logistax_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  if (InternConfig.isConfigured) {
    test('dilewati — hanya untuk build tanpa INTERN_API_URL', () {}, skip: true);
    return;
  }

  testWidgets('tanpa INTERN_API_URL: toggle Magang tidak ada, sesi intern diabaikan',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'last_active_session': 'intern',
      'login_mode': 'intern',
    });
    await InternStorage.saveSession(
      'intern-token',
      const InternProfile(id: '1', fullName: 'X', nim: '1', status: 'active').encode(),
    );

    await tester.pumpWidget(const ProviderScope(child: LogistaxApp()));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(InternHomePage), findsNothing);
    expect(find.byType(SegmentedButton<SessionKind>), findsNothing);
    expect(find.text('Magang'), findsNothing);
    expect(find.text('Lupa Password?'), findsOneWidget);
  });
}
