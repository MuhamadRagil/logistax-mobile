// Pengaman supaya fitur intern tidak hilang dari rilis tanpa disadari.
//
// - Pemeriksaan keberadaan file/kode kunci selalu berjalan.
// - Pemeriksaan konfigurasi hanya aktif bila dijalankan dengan define:
//     flutter test --dart-define=INTERN_API_URL=https://intern.test/api
//   Tanpa define (mesin dev biasa) bagian itu dilewati dengan pesan jelas.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logistax_mobile/core/storage/session_prefs.dart';
import 'package:logistax_mobile/features/intern/data/intern_api_client.dart';
import 'package:logistax_mobile/features/intern/data/intern_repository.dart';
import 'package:logistax_mobile/features/intern/data/intern_storage.dart';
import 'package:logistax_mobile/features/intern/intern_config.dart';
import 'package:logistax_mobile/features/intern/providers/intern_session.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('konfigurasi build (butuh --dart-define=INTERN_API_URL)', () {
    const defined = bool.hasEnvironment('INTERN_API_URL');

    test(
      'INTERN_API_URL diberikan => InternConfig.isConfigured harus true',
      () {
        expect(
          InternConfig.isConfigured,
          isTrue,
          reason: 'INTERN_API_URL diberikan tetapi kosong. Toggle Karyawan/Magang '
              'akan hilang dari APK. Beri URL yang valid.',
        );
        expect(InternConfig.apiUrl, startsWith('http'));
      },
      skip: defined
          ? false
          : 'INTERN_API_URL tidak diberikan (mode dev). Jalankan: '
              'flutter test --dart-define=INTERN_API_URL=https://intern.test/api',
    );
  });

  group('kode kunci intern masih ada', () {
    test('file inti intern ada dan tidak kosong', () {
      for (final path in const [
        'lib/features/intern/intern_config.dart',
        'lib/features/intern/data/intern_api_client.dart',
        'lib/features/intern/data/intern_repository.dart',
        'lib/features/intern/data/intern_storage.dart',
        'lib/features/intern/providers/intern_session.dart',
        'lib/features/intern/presentation/intern_shell.dart',
        'lib/core/storage/session_prefs.dart',
      ]) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: '$path hilang — fitur intern terhapus?');
        expect(f.lengthSync(), greaterThan(0), reason: '$path kosong');
      }
    });

    test('kelas kunci intern masih ada', () {
      expect(InternConfig.apiUrl, isA<String>());
      expect(InternSessionController, isNotNull);
      expect(InternApiClient, isNotNull);
      expect(InternRepository, isNotNull);
      expect(InternStorage, isNotNull);
      expect(SessionKind.values, containsAll([SessionKind.hr, SessionKind.intern]));
    });

    test('router masih punya route /intern/*', () {
      final router = _read('lib/core/router/app_router.dart');
      expect(router, contains("path: '/intern'"), reason: 'route /intern hilang dari router');
      expect(router, contains('internSessionProvider'), reason: 'router tidak lagi membaca sesi intern');
    });

    test('login & splash masih mempertahankan alur sesi intern', () {
      final login = _read('lib/features/auth/presentation/pages/login_page.dart');
      expect(login, contains('InternConfig.isConfigured'), reason: 'toggle Karyawan/Magang hilang dari login');
      expect(login, contains('SessionKind'));
      expect(login, contains('internSessionProvider'));

      final splash = _read('lib/features/auth/presentation/pages/splash_page.dart');
      expect(splash, contains('internSessionProvider'), reason: 'splash tidak lagi memulihkan sesi intern');
      expect(splash, contains('shouldRestoreFirst'));
    });
  });
}
