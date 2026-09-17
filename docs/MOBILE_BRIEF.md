# Logistax Mobile — Brief untuk Code Generator

Project: `d:\laragon\www\projects\logistax_mobile` — Flutter 3.44 / Dart 3.12, Material 3, flutter_riverpod 2.x (TANPA codegen — provider manual), go_router 14 (StatefulShellRoute), dio. Backend: `http://10.0.2.2:3001/api`. Firebase/FCM SENGAJA tidak dipakai (belum ada google-services.json) — jangan import firebase.

## Fondasi SUDAH ADA — pakai, JANGAN dimodifikasi

| File | Isi |
|---|---|
| `lib/core/constants/api_constants.dart` | Semua endpoint (SUDAH dikoreksi sesuai backend nyata — jangan mengarang endpoint lain) |
| `lib/core/constants/app_colors.dart` | navy/teal/semantic + `AppColors.attendanceStatus(status)`, `AppColors.kpiTier(tier)` |
| `lib/core/constants/app_strings.dart` | label Indonesia: `attendanceStatusLabel`, `leaveStatusLabel`, `kpiTierLabel`, `loanStatusLabel`, `employmentStatusLabel`, `roleLabel`, `bulan`, `hari` |
| `lib/core/theme/app_theme.dart` | lightTheme()/darkTheme() |
| `lib/core/network/dio_client.dart` | `DioClient.instance` (Bearer + auto-refresh 401) |
| `lib/core/network/api_exception.dart` | `ApiException.fromDio(e).message` — SELALU pakai ini untuk pesan error |
| `lib/core/storage/secure_storage.dart` | token & user |
| `lib/core/utils/currency_util.dart` | `formatRupiah(num?)`, `formatNumber` |
| `lib/core/utils/date_util.dart` | `formatDateLong/Full/Short`, `formatTime`, `formatTimeWib`, `monthLabel(m,y)`, `toApiDate(DateTime)`, `countWorkingDays(start,end)` |
| `lib/core/utils/haversine_util.dart` | `haversineMeters(...)` |
| `lib/core/providers/theme_provider.dart` | `themeModeProvider` + `.notifier.setMode(ThemeMode)` (persisted) |
| `lib/shared/models/*.dart` | `AppUser`, `EmployeeSummary`, `EmployeeProfile`, `TeamMember`, `AttendanceRecord`, `AttendanceSummary`, `AttendanceMonthly(-Employee)`, `TodayBoardItem`, `LeaveType`, `LeaveBalance`, `LeaveRequest`, `KpiSummary`, `KpiMonthly`, `KpiBreakdownItem`, `KpiTrendPoint`, `KpiEmployeeDetail`, `Payslip`, `EmployeeLoan`, `AppNotification` — semua punya `fromJson`; angka uang di-parse via `toNum` (backend kirim Decimal sebagai string) |
| `lib/shared/widgets/` | `AppButton(label,onPressed,loading,icon,outlined,color)`, `AppTextField(controller,label,...)`, `StatusBadge(label,color,fontSize)`, `KpiTierBadge(tier)`, `LoadingShimmer(count,height)`, `EmptyState(icon,title,description,action)`, `ErrorState(error,onRetry)`, `LogistaxLogo(fontSize,color)`, `LogistaxAppBar(title,actions,bottom)` (sudah berisi lonceng notifikasi + badge unread), `BottomNavShell` (jangan sentuh) |
| `lib/shared/providers/badge_providers.dart` | `unreadNotificationsProvider`, `myPendingLeaveCountProvider` (invalidate setelah aksi terkait) |
| `lib/features/auth/providers/auth_provider.dart` | `authControllerProvider` (ChangeNotifierProvider) → `.status`, `.user` (AppUser), `.employeeId`, `.isSpv`, `.canSeeTeam`, `.login(email,pass)`, `.logout()`, `.resumeSession()`, `.refreshProfile()` |
| `lib/features/auth/data/auth_repository.dart` | login/me/forgotPassword/resetPassword/changePassword/logoutServer |
| `lib/core/router/app_router.dart` | SEMUA route sudah terdaftar (jangan ubah) — lihat kontrak halaman di bawah |

## KONTRAK HALAMAN (nama class + path file + konstruktor HARUS PERSIS — router sudah mengimpornya)

| Route | File | Class & konstruktor |
|---|---|---|
| /login | `lib/features/auth/presentation/pages/login_page.dart` | `LoginPage()` const |
| /forgot | `.../forgot_password_page.dart` | `ForgotPasswordPage()` const |
| /reset?token= | `.../reset_password_page.dart` | `ResetPasswordPage({String? token})` |
| / | `lib/features/home/presentation/pages/home_page.dart` | `HomePage()` const |
| /absensi | `lib/features/attendance/presentation/pages/attendance_status_page.dart` | `AttendanceStatusPage()` const |
| /absensi/scan?tujuan=checkin\|checkout | `.../qr_scanner_page.dart` | `QrScannerPage({required ScanPurpose purpose})` + `enum ScanPurpose { checkIn, checkOut }` (definisikan di file ini) |
| /absensi/sukses | `.../scan_success_page.dart` | `ScanSuccessPage({required Map<String, dynamic> result})` — result: `{'type': 'checkin'/'checkout', 'record': <raw record map>}` |
| /absensi/riwayat | `.../attendance_history_page.dart` | `AttendanceHistoryPage()` const |
| /cuti | `lib/features/leave/presentation/pages/leave_balance_page.dart` | `LeaveBalancePage()` const |
| /cuti/ajukan | `.../leave_form_step1_page.dart` | `LeaveFormStep1Page()` const |
| /cuti/ajukan/2 | `.../leave_form_step2_page.dart` | `LeaveFormStep2Page()` const |
| /cuti/konfirmasi | `.../leave_confirm_page.dart` | `LeaveConfirmPage()` const |
| /cuti/riwayat | `.../leave_history_page.dart` | `LeaveHistoryPage()` const |
| /kpi | `lib/features/kpi/presentation/pages/my_kpi_page.dart` | `MyKpiPage()` const |
| /kpi/riwayat | `.../kpi_history_page.dart` | `KpiHistoryPage()` const |
| /kpi/leaderboard | `.../kpi_leaderboard_page.dart` | `KpiLeaderboardPage()` const |
| /slip | `lib/features/payroll/presentation/pages/payslip_list_page.dart` | `PayslipListPage()` const |
| /slip/:id (extra: Payslip?) | `.../payslip_detail_page.dart` | `PayslipDetailPage({required String slipId, Payslip? initial})` |
| /slip/bagikan (extra: Payslip) | `.../payslip_share_page.dart` | `PayslipSharePage({required Payslip slip})` |
| /pinjaman | `lib/features/loans/presentation/pages/loan_status_page.dart` | `LoanStatusPage()` const |
| /pinjaman/riwayat (extra: EmployeeLoan?) | `.../loan_history_page.dart` | `LoanHistoryPage({EmployeeLoan? loan})` |
| /notifikasi | `lib/features/notifications/presentation/pages/notifications_page.dart` | `NotificationsPage()` const |
| /notifikasi/detail (extra: AppNotification) | `.../notification_detail_page.dart` | `NotificationDetailPage({required AppNotification notification})` |
| /profil | `lib/features/profile/presentation/pages/profile_page.dart` | `ProfilePage()` const |
| /profil/edit | `.../edit_profile_page.dart` | `EditProfilePage()` const |
| /profil/password | `.../change_password_page.dart` | `ChangePasswordPage()` const |
| /profil/notifikasi | `.../notification_settings_page.dart` | `NotificationSettingsPage()` const |
| /spv/tim | `lib/features/spv/presentation/pages/team_attendance_page.dart` | `TeamAttendancePage()` const |

Navigasi: `context.push('/route')` untuk halaman bertumpuk, `context.go('/')` untuk pindah tab. Halaman di dalam shell (tab + subroute riwayat/profil) otomatis punya bottom nav; halaman fullscreen (scan, sukses, form cuti, kpi, slip, pinjaman, notifikasi) tidak.

## Aturan wajib

1. Halaman = `ConsumerWidget`/`ConsumerStatefulWidget` (flutter_riverpod). Data fetch pakai `FutureProvider.autoDispose` (+`.family` bila perlu param) di file `providers/` fitur masing-masing, `ref.watch(provider).when(data/loading/error)` dengan `LoadingShimmer` dan `ErrorState(error, onRetry: () => ref.invalidate(provider))`.
2. Repository per fitur di `data/` memakai `DioClient.instance`; bungkus error `throw ApiException.fromDio(e)`. Envelope sukses: `res.data['data']` (paginated: `res.data['meta']` berisi `{page,limit,total,totalPages}`).
3. SnackBar error merah: `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error))`. Sukses pakai `AppColors.success`.
4. Foto profil: `CircleAvatar` + `CachedNetworkImageProvider(photoUrl)` bila ada, fallback inisial nama.
5. Semua teks UI Bahasa Indonesia. Tanggal via date_util, uang via formatRupiah.
6. `employeeId` saya: `ref.read(authControllerProvider).employeeId` (bisa null → tampilkan pesan "Akun tidak terhubung dengan data karyawan").
7. Pull-to-refresh (`RefreshIndicator` + `ref.invalidate`) di halaman list/status.
8. Dark mode: JANGAN hardcode warna teks/permukaan — pakai `Theme.of(context)` (kecuali slip gaji: SELALU putih, teks hitam eksplisit — dokumen resmi).
9. Jangan buat/ubah file di luar daftar tugasmu; jangan sentuh router, main.dart, shared, core. Jangan jalankan flutter run/build (analyze file kamu sendiri boleh: `flutter analyze lib/features/<fitur>`).
10. Dart 3.12 + flutter_lints 6: gunakan `withValues(alpha: x)` bukan `withOpacity`, super parameters, `const` di mana bisa.

## Referensi API (yang relevan untuk mobile; role employee kecuali disebut)

Envelope sukses `{success, data, message, meta?}`; error `{success:false, error, statusCode}`.

### Auth
- `POST /auth/login {email, password}` → data `{user{id,email,role,employee{id,nik,fullName,photoUrl,department{name},position{name}}|null}, accessToken, refreshToken}`
- `POST /auth/forgot-password {email}` (selalu sukses); `POST /auth/reset-password {token, newPassword(min 8)}`; `POST /auth/change-password {currentPassword, newPassword}`
- `GET /users/me` → user + `employee` LENGKAP (semua field EmployeeProfile + department/position/supervisor)

### Absensi
- `GET /attendance/me/today` → AttendanceRecord saya hari ini ATAU `null` (belum absen)
- `POST /attendance/check-in {token(dari QR), latitude, longitude}` → record + `distanceMeters`; error 400 dengan pesan Indonesia bila: QR expired, di luar radius, sudah check-in
- `POST /attendance/check-out {latitude, longitude, notes?}` → record. CATATAN: check-out TIDAK butuh token QR (tetap boleh lewat scanner utk UX, abaikan tokennya)
- `GET /attendance/monthly?year=&month=` → untuk role employee otomatis hanya diri sendiri; `employees[0]` berisi `summary` + `records` per hari
- `GET /attendance/today` → HANYA hrd/spv (semua karyawan: `{date,total,checkedIn,employees:[{employee,status,record}]}`) — dipakai halaman SPV
- `GET /settings/attendance` → `{workStartTime,"HH:mm",workEndTime,lateToleranceMinutes,officeLatitude,officeLongitude,gpsRadiusMeters,qrRefreshSeconds}`

### Cuti
- `GET /leave/types` → LeaveType[]
- `GET /leave/balances/me?year=` → LeaveBalance[] (sisa = totalDays+carryOverDays-usedDays)
- `GET /leave/requests/my` → LeaveRequest[] milik saya
- `POST /leave/requests {leaveTypeId, startDate 'YYYY-MM-DD', endDate, reason, documentUrl?}` — CATATAN: upload dokumen ke server TIDAK tersedia (tidak ada endpoint upload); kirim tanpa documentUrl dan beri catatan di UI
- `PATCH /leave/requests/:id/review {status:'approved'|'rejected', rejectionReason?}` — hrd/spv (BUKAN {action:...})
- `PATCH /leave/requests/:id/cancel` — batalkan pengajuan pending milik sendiri
- `GET /leave/requests?status=pending` — hrd/spv (spv otomatis hanya bawahan) — untuk halaman approval SPV

### KPI
- `GET /kpi/monthly?year=&month=` → `{period{year,month,monthName}, finalized, employeeOfTheMonth|null, leaderboard[]}` — role employee DITOLAK (error) sebelum finalized → tangani sebagai "Nilai KPI belum tersedia bulan ini"
- `GET /kpi/employee/:employeeId?year=&month=` → `{employee, period, breakdown[], summary|null, trend[]}` — boleh akses milik sendiri

### Lembur (kartu home)
- `GET /overtime?year=&month=&status=approved` → paginated; role employee otomatis hanya miliknya; jumlahkan `totalHours`

### Slip Gaji
- `GET /payroll/employee/:employeeId` → Payslip[] milik sendiri (BUKAN /employees/:id/payslips)
- `GET /payroll/slips/:id` → Payslip detail; `GET /payroll/slips/:id/pdf` → BINARY PDF (password = 6 digit terakhir NIK; `slip.pdfPasswordHint`). Download: dio `Options(responseType: ResponseType.bytes)` → simpan via path_provider → buka `OpenFilex.open(path)` / bagikan `Share.shareXFiles`

### Pinjaman
- `GET /loans/me` → EmployeeLoan[] (BUKAN /employees/:id/loans); tidak ada endpoint riwayat cicilan → jadwal dihitung client-side dari model (getter paid/progress/remainingMonths sudah ada)

### Notifikasi
- `GET /notifications?page=&limit=&unreadOnly=true` → paginated AppNotification[]
- `PATCH /notifications/:id/read`; `PATCH /notifications/read-all`; `GET /notifications/unread-count` → `{unread}`

### Tim (SPV)
- `GET /employees?limit=100` (hrd/spv) → filter client-side `supervisorId == employeeId saya` untuk daftar tim; gabungkan dengan `/attendance/today`

### Yang TIDAK ada di backend (JANGAN dibuat-buat):
- Update profil sendiri / upload foto sendiri (PUT /employees/:id itu hrd-only) → halaman Edit Profil dibuat READ-ONLY dengan pesan "Hubungi HRD untuk mengubah data"
- Endpoint upload dokumen cuti, riwayat cicilan pinjaman, holiday/libur nasional
