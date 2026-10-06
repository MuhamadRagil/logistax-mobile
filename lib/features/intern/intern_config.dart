/// Konfigurasi backend Sistem Manajemen Magang (Laravel) — terpisah dari
/// backend HR.
///
/// Diisi saat build: `--dart-define=INTERN_API_URL=https://<host>/api`
/// (sertakan `/api`, sama seperti `API_URL` untuk HR). Sengaja TANPA default:
/// selama belum diisi, mode Magang disembunyikan dari layar login sehingga
/// APK berperilaku persis seperti versi karyawan saja.
class InternConfig {
  InternConfig._();

  static const String apiUrl = String.fromEnvironment('INTERN_API_URL');

  static bool get isConfigured => apiUrl.isNotEmpty;
}

class InternEndpoints {
  InternEndpoints._();

  static const String login = '/auth/intern/login';
  static const String logout = '/auth/logout';
  static const String checkIn = '/attendance/check-in'; // {latitude, longitude}
  static const String checkOut = '/attendance/check-out'; // {latitude, longitude}
  static const String leaveRequest = '/attendance/leave-request'; // multipart
  static const String myHistory = '/attendance/my-history'; // ?month=&year=
  static const String myEvaluation = '/my-evaluation';
  static const String myCertificate = '/my-certificate';
  static const String myCertificateDownload = '/my-certificate/download';
}
