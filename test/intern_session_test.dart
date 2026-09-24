// Jalankan dengan backend magang "terkonfigurasi" (URL dummy, tidak dihubungi):
//   flutter test --dart-define=INTERN_API_URL=https://intern.test/api
//
// Menguji app utuh (router + splash + login) dengan secure storage &
// SharedPreferences tiruan. Semua HTTP di flutter_test otomatis dibalas 400,
// sehingga validasi sesi HR ke server selalu gagal — dipakai untuk menguji
// jalur "sesi karyawan tidak valid".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logistax_mobile/core/storage/secure_storage.dart';
import 'package:logistax_mobile/core/storage/session_prefs.dart';
import 'package:logistax_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:logistax_mobile/features/intern/data/intern_storage.dart';
import 'package:logistax_mobile/features/intern/intern_config.dart';
import 'package:logistax_mobile/features/intern/models/intern_models.dart';
import 'package:logistax_mobile/features/intern/presentation/pages/intern_home_page.dart';
import 'package:logistax_mobile/features/intern/presentation/pages/intern_profile_page.dart';
import 'package:logistax_mobile/features/intern/providers/intern_session.dart';
import 'package:logistax_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = InternProfile(
  id: '7',
  fullName: 'Budi Intern',
  nim: '2210511001',
  institution: 'UPN',
  startDate: '2026-08-01',
  endDate: '2026-12-31',
  status: 'active',
);

Future<void> _seed({bool hr = false, bool intern = false, String? lastActive}) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({'last_active_session': ?lastActive});
  if (hr) {
    await SecureStorage.saveTokens('hr-access', 'hr-refresh');
    await SecureStorage.saveUser('{"id":"1","email":"k@logistax.id","role":"employee"}');
  }
  if (intern) await InternStorage.saveSession('intern-token', _profile.encode());
}

/// Splash punya jeda minimum 1,4 detik + animasi → pump bertahap, bukan
/// pumpAndSettle (indikator loading berputar terus).
Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: LogistaxApp()));
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  if (!InternConfig.isConfigured) {
    test('dilewati — jalankan dengan --dart-define=INTERN_API_URL=https://intern.test/api', () {},
        skip: true);
    return;
  }

  group('tanggal dari backend magang', () {
    test('server Asia/Jakarta: tengah malam WIB dikirim sebagai 17:00Z hari sebelumnya', () {
      expect(dateKeyOf('2026-09-23T17:00:00.000000Z'), '2026-09-24');
    });
    test('server UTC: tengah malam UTC tetap hari yang sama', () {
      expect(dateKeyOf('2026-09-24T00:00:00.000000Z'), '2026-09-24');
    });
    test('format yyyy-MM-dd dipakai apa adanya', () {
      expect(dateKeyOf('2026-09-24'), '2026-09-24');
      expect(dateKeyOf(null), isNull);
    });
  });

  group('isolasi token', () {
    test('SecureStorage.clear() HR tidak menghapus sesi intern', () async {
      await _seed(hr: true, intern: true);
      await SecureStorage.clear();
      expect(await SecureStorage.getAccessToken(), isNull);
      expect(await SecureStorage.getRefreshToken(), isNull);
      expect(await SecureStorage.getUser(), isNull);
      expect(await InternStorage.getToken(), 'intern-token');
    });

    test('InternStorage.clear() tidak menghapus sesi karyawan', () async {
      await _seed(hr: true, intern: true);
      await InternStorage.clear();
      expect(await InternStorage.getToken(), isNull);
      expect(await SecureStorage.getAccessToken(), 'hr-access');
      expect(await SecureStorage.getRefreshToken(), 'hr-refresh');
    });
  });

  group('prioritas sesi di splash (last_active_session)', () {
    Future<bool> restoreFirst() => InternSessionController().shouldRestoreFirst();

    test('tanpa token intern → selalu alur karyawan', () async {
      await _seed(hr: true, lastActive: 'intern');
      expect(await restoreFirst(), isFalse);
    });

    test('dua sesi, terakhir intern → intern', () async {
      await _seed(hr: true, intern: true, lastActive: 'intern');
      expect(await restoreFirst(), isTrue);
    });

    test('dua sesi, terakhir karyawan → karyawan', () async {
      await _seed(hr: true, intern: true, lastActive: 'hr');
      expect(await restoreFirst(), isFalse);
    });

    test('hanya sesi intern (flag hr basi) → intern', () async {
      await _seed(intern: true, lastActive: 'hr');
      expect(await restoreFirst(), isTrue);
    });
  });

  group('alur app utuh', () {
    testWidgets('tanpa sesi → login mode Karyawan (default)', (tester) async {
      await _seed();
      await _boot(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Karyawan'), findsOneWidget);
      expect(find.text('Lupa Password?'), findsOneWidget);
      final toggle = tester.widget<SegmentedButton<SessionKind>>(
        find.byType(SegmentedButton<SessionKind>),
      );
      expect(toggle.selected, {SessionKind.hr});
    });

    testWidgets('pilihan toggle terakhir (Magang) diingat', (tester) async {
      await _seed();
      SharedPreferences.setMockInitialValues({'login_mode': 'intern'});
      await _boot(tester);
      final toggle = tester.widget<SegmentedButton<SessionKind>>(
        find.byType(SegmentedButton<SessionKind>),
      );
      expect(toggle.selected, {SessionKind.intern});
      expect(find.text('Lupa Password?'), findsNothing);
    });

    testWidgets('sesi intern terakhir aktif → langsung ke beranda magang', (tester) async {
      await _seed(hr: true, intern: true, lastActive: 'intern');
      await _boot(tester);
      expect(find.byType(InternHomePage), findsOneWidget);
      expect(find.text('Halo, Budi Intern'), findsOneWidget);
      // Validasi sesi HR dilewati → token karyawan tetap utuh.
      expect(await SecureStorage.getAccessToken(), 'hr-access');
    });

    testWidgets('sesi karyawan gagal divalidasi → token intern tetap, dipakai sebagai cadangan',
        (tester) async {
      await _seed(hr: true, intern: true, lastActive: 'hr');
      await _boot(tester);
      // HR divalidasi dulu (flag = hr), gagal → SecureStorage.clear() HR.
      expect(await SecureStorage.getAccessToken(), isNull);
      // Token intern tidak ikut terhapus dan sesi intern dipulihkan.
      expect(await InternStorage.getToken(), 'intern-token');
      expect(find.byType(InternHomePage), findsOneWidget);
    });

    testWidgets('logout intern → layar login, token karyawan tidak disentuh', (tester) async {
      // Layar setinggi HP agar menu Keluar di bawah daftar profil ter-render.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await _seed(hr: true, intern: true, lastActive: 'intern');
      await _boot(tester);

      await tester.tap(find.text('Profil'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(InternProfilePage), findsOneWidget);

      await tester.tap(find.text('Keluar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(LoginPage), findsOneWidget);
      expect(await InternStorage.getToken(), isNull);
      expect(await SecureStorage.getAccessToken(), 'hr-access');
      expect(await SecureStorage.getRefreshToken(), 'hr-refresh');
    });
  });
}
