# Logistax Mobile

Aplikasi mobile Flutter untuk karyawan & supervisor Logistax (absensi QR + GPS, cuti, KPI, slip gaji, pinjaman, notifikasi).

Brand: Navy `#003087` · Teal `#00A6C0`

## Menjalankan

Backend harus berjalan lebih dulu (`logistax-api`, port 3001).

```bash
flutter pub get

# Emulator Android (default sudah 10.0.2.2)
flutter run

# iOS Simulator
flutter run --dart-define=API_URL=http://localhost:3001/api

# Perangkat fisik — pakai IP LAN komputer (cek dengan ipconfig)
flutter run --dart-define=API_URL=http://192.168.1.10:3001/api
```

Build APK: `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`

## Build Release

Satu APK dipakai karyawan dan intern. Fitur intern (`lib/features/intern/`) harus
selalu ada, dan toggle Karyawan/Magang hanya muncul bila APK dibangun dengan
`INTERN_API_URL`. Rilis hanya dari `master` yang bersih dan ter-pull:

```powershell
.\scripts\build_release.ps1      # Windows (atau: bash scripts/build_release.sh)
```

Perintah yang dijalankan skrip (satu-satunya yang benar):

```
flutter build apk --release --dart-define=INTERN_API_URL=https://logistax-magang-production.up.railway.app/api
```

Naikkan build number setelah `+` di `pubspec.yaml` tiap rilis. Hasil disalin ke
`build/app/outputs/flutter-apk/logistax-absen-<versi>.apk`. Aturan lengkap: `CLAUDE.md`.

## Menguji scan QR

1. Login di web dashboard (`logistax-web`) sebagai HRD.
2. Buka `http://localhost:3000/qr-station` di layar terpisah.
3. Di aplikasi: tab **Absensi** → **Scan QR Check-In** → arahkan kamera ke QR.

Emulator: aktifkan kamera virtual (AVD → Camera → Webcam0) dan set lokasi GPS di Extended Controls agar berada dalam radius kantor (lihat `GET /settings/attendance` untuk koordinat & radius).

Check-out tidak memerlukan token QR (backend hanya meminta koordinat), tetapi alur UI tetap lewat scanner agar konsisten.

## Arsitektur

```
lib/
├── core/          konstanta, tema, dio client, secure storage, router, util
├── shared/        model (fromJson), widget reusable, provider badge
└── features/      auth, home, attendance, leave, kpi, payroll, loans,
                   notifications, profile, spv
                   └── data/ (repository) · providers/ · presentation/pages/
```

State: `flutter_riverpod` (provider manual, tanpa codegen). Routing: `go_router` dengan `StatefulShellRoute` untuk bottom navigation dan redirect guard berbasis `AuthController`.

Bottom nav: Beranda · Absensi · Cuti · **Tim** (hanya spv/hrd/super_admin) · Profil.

## Catatan integrasi backend

Beberapa hal berbeda dari draft spec awal karena disesuaikan dengan API yang benar-benar ada:

| Kebutuhan | Endpoint sebenarnya |
|---|---|
| Absensi saya hari ini | `GET /attendance/me/today` |
| Check-out | `POST /attendance/check-out` — **tanpa** token QR |
| Saldo cuti saya | `GET /leave/balances/me?year=` |
| Pengajuan cuti saya | `GET /leave/requests/my` |
| Approve/reject cuti | `PATCH /leave/requests/:id/review` body `{status:'approved'\|'rejected', rejectionReason?}` |
| Slip gaji saya | `GET /payroll/employee/:employeeId` |
| Pinjaman saya | `GET /loans/me` |

Fitur yang **tidak** tersedia di backend, sehingga UI-nya dibuat read-only/informasional dengan penjelasan di layar:

- Update profil & upload foto oleh karyawan sendiri (`PUT /employees/:id` khusus HRD) → halaman Edit Profil read-only.
- Upload dokumen pendukung cuti → file picker hanya penanda lokal, tidak dikirim.
- Riwayat cicilan pinjaman → jadwal dihitung di client dari sisa pinjaman.
- Hari libur nasional/perusahaan.

## Firebase / Push Notification

Belum diaktifkan (butuh `google-services.json` dari Firebase Console). Notifikasi dalam aplikasi lewat `GET /notifications` sudah berfungsi penuh, termasuk badge unread di AppBar. Setelah Firebase dikonfigurasi, tambahkan `firebase_core` + `firebase_messaging`, lalu daftarkan token via `POST /notifications/fcm-token`.

## Status verifikasi

Diuji end-to-end di emulator Android 13 (API 33) dengan backend berjalan:

- Login `hrd@logistax.id` → token tersimpan → Beranda menampilkan data nyata (status absensi, saldo cuti, KPI 70.1 tier "Baik", lembur, 3 notifikasi terbaru, badge 4 unread).
- Auto-login dari sesi tersimpan berfungsi (restart aplikasi langsung ke Beranda).
- Tab Absensi, Cuti (4 jenis cuti dari backend), dan Tim (khusus hrd/spv) render benar.
- Pesan error backend tampil rapi (kredensial salah → "Email atau password salah" inline merah).
- Tidak ada crash/ANR dari aplikasi di logcat.

Belum diuji langsung (butuh interaksi perangkat keras/data tambahan): scan QR dengan kamera, check-in/out GPS, unduh PDF slip, dan login biometrik.

## Penyesuaian build Android

Tiga hal di `android/gradle.properties` & `pubspec.yaml` yang perlu diketahui bila nanti meng-upgrade dependency:

- `file_picker` dinaikkan ke **11.0.0**. Versi 8.x/10.x mengunci `compileSdk 34` di dalam paketnya, sementara dependency transitifnya (`flutter_plugin_android_lifecycle`) menuntut API 36 → `checkDebugAarMetadata` gagal. Versi 11 memakai `flutter.compileSdkVersion` sehingga ikut app. API-nya juga berubah: `FilePicker.pickFiles(...)` (statis), bukan `FilePicker.platform.pickFiles(...)`.
- `kotlin.incremental=false` — cache incremental Kotlin sering gagal ditutup di Windows ("Could not close incremental caches") dan membuat build gagal acak.
- `kotlin.jvm.target.validation.mode=warning` — `file_picker` meng-compile Kotlin ke JVM 21 sementara Java-nya 17; tanpa ini Gradle menolak build.

Build juga memunculkan peringatan "Built-in Kotlin" dari beberapa plugin yang belum bermigrasi. Itu peringatan, bukan error — akan hilang seiring plugin diperbarui.

## Izin Android

`CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET`, `USE_BIOMETRIC`, `USE_FINGERPRINT`. `MainActivity` memakai `FlutterFragmentActivity` (syarat `local_auth`). `usesCleartextTraffic=true` agar bisa mengakses backend HTTP saat pengembangan — **hapus untuk rilis produksi (HTTPS)**.
