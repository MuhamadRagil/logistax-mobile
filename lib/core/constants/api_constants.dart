/// Endpoint API Logistax — path sesuai backend NestJS yang berjalan.
/// PENTING: beberapa path berbeda dari draft spec; ini yang benar.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://logistax-api-production.up.railway.app/api',
  );

  // ── Auth ──────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String changePassword = '/auth/change-password';
  static const String me = '/users/me';

  // ── Attendance ────────────────────────────────────────
  static const String checkIn = '/attendance/check-in'; // {latitude, longitude} — GPS saja, tanpa QR
  static const String checkOut = '/attendance/check-out'; // {latitude, longitude, notes?} — GPS saja, tanpa QR
  static const String attendanceMeToday = '/attendance/me/today'; // record saya hari ini / null
  static const String attendanceToday = '/attendance/today'; // hrd/spv saja (semua karyawan)
  static const String attendanceMonthly = '/attendance/monthly'; // ?year=&month=&employeeId=
  static const String attendanceSettings = '/settings/attendance';

  // ── Leave ─────────────────────────────────────────────
  static const String leaveTypes = '/leave/types';
  static const String leaveBalancesMe = '/leave/balances/me'; // ?year=
  static const String leaveRequests = '/leave/requests'; // hrd/spv (spv = bawahan saja)
  static const String myLeaveRequests = '/leave/requests/my';
  static const String leaveDocumentUpload = '/leave/requests/upload-document'; // POST multipart, field 'file'
  static String leaveReview(String id) => '/leave/requests/$id/review'; // PATCH {status, rejectionReason?}
  static String leaveCancel(String id) => '/leave/requests/$id/cancel';

  // ── KPI ───────────────────────────────────────────────
  static const String kpiMonthly = '/kpi/monthly'; // ?year=&month= (employee: hanya setelah finalized)
  static String kpiEmployee(String id) => '/kpi/employee/$id'; // ?year=&month=

  // ── Overtime ──────────────────────────────────────────
  static const String overtime = '/overtime'; // ?year=&month=&status=

  // ── Payroll ───────────────────────────────────────────
  static String myPayslips(String employeeId) => '/payroll/employee/$employeeId';
  static String slip(String id) => '/payroll/slips/$id';
  static String slipPdf(String id) => '/payroll/slips/$id/pdf'; // binary PDF (password: 6 digit akhir NIK)

  // ── Loans ─────────────────────────────────────────────
  static const String myLoans = '/loans/me'; // array pinjaman saya

  // ── Notifications ─────────────────────────────────────
  static const String notifications = '/notifications'; // ?page=&limit=&unreadOnly=true
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all'; // PATCH
  static String notificationRead(String id) => '/notifications/$id/read'; // PATCH
  static const String fcmToken = '/notifications/fcm-token';

  // ── Employees (SPV: daftar tim) ───────────────────────
  static const String employees = '/employees'; // hrd/spv
  static String employeeLocations(String id) => '/employees/$id/locations';
  static const String employeeMeProfile = '/employees/me/profile'; // PATCH {phone, address}
  static const String employeeMePhoto = '/employees/me/photo'; // PATCH multipart, field 'file'
}
