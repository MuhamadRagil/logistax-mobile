# Logistax Mobile — aturan proyek

## Satu APK untuk karyawan dan intern
- Satu APK dipakai karyawan (backend HR, NestJS) dan intern (backend magang, Laravel).
- Fitur intern (`lib/features/intern/`) WAJIB ada di setiap rilis.
- Toggle Karyawan/Magang di layar login hanya muncul jika APK dibangun dengan
  `--dart-define=INTERN_API_URL=...` (`InternConfig.isConfigured`). Tanpa define,
  toggle hilang dan APK jadi versi karyawan saja.

## Build rilis
- Rilis hanya dibangun dari branch `master`, working tree bersih, sudah ter-pull.
- Perintah build rilis yang benar (satu-satunya):

  ```
  flutter build apk --release --dart-define=INTERN_API_URL=https://logistax-magang-production.up.railway.app/api
  ```

- Gunakan skrip `scripts/build_release.ps1` (Windows) atau `scripts/build_release.sh`;
  keduanya menjalankan pemeriksaan pengaman, membangun, lalu memverifikasi isi APK.
- Naikkan build number setelah `+` di `pubspec.yaml` pada setiap rilis
  (mis. `1.0.1+2` -> `1.0.1+3`), dan pakai keystore release yang sama
  (`android/key.properties`, jangan di-commit).
- Hasil build disalin ke nama berversi `logistax-absen-X.Y.Z.apk` karena
  `app-release.apk` selalu tertimpa build berikutnya.

## Yang tidak boleh dilakukan tanpa persetujuan eksplisit pemilik proyek
- Menghapus atau memindahkan `lib/features/intern/`, `intern_config.dart`,
  `intern_api_client.dart`, atau route `/intern/*` di router.
- Membangun rilis dari branch selain `master`, atau tanpa `--dart-define=INTERN_API_URL`.
- Mengubah URL backend magang lewat argumen build.

## Saat mengubah alur login/sesi
Setiap perubahan di `login_page.dart`, `splash_page.dart`, `app_router.dart`, atau
`main.dart` harus mempertahankan alur sesi intern: `SessionPrefs`, `SessionKind`,
dan `internSessionProvider` (`InternSessionController`). `test/intern_guard_test.dart`
menangkap penghapusan yang tidak sengaja.

Cek pengaman:

```
flutter test --dart-define=INTERN_API_URL=https://intern.test/api
```
