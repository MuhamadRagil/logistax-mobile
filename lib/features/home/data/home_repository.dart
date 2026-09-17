import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/kpi_model.dart';
import '../../../shared/models/leave_model.dart';
import '../../../shared/models/model_utils.dart';
import '../../../shared/models/notification_model.dart';

/// Sumber data untuk halaman Beranda.
class HomeRepository {
  final _dio = DioClient.instance;

  /// Record absensi saya hari ini — `null` bila belum absen.
  Future<AttendanceRecord?> myToday() async {
    try {
      final res = await _dio.get(ApiConstants.attendanceMeToday);
      final data = res.data['data'];
      if (data is Map<String, dynamic>) return AttendanceRecord.fromJson(data);
      return null;
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Saldo cuti saya untuk tahun tertentu.
  Future<List<LeaveBalance>> myBalances(int year) async {
    try {
      final res = await _dio.get(
        ApiConstants.leaveBalancesMe,
        queryParameters: {'year': year},
      );
      return (res.data['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(LeaveBalance.fromJson)
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Detail KPI saya bulan ini — bisa error (belum finalized); caller yang menangani.
  Future<KpiEmployeeDetail?> myKpi(String employeeId, int year, int month) async {
    try {
      final res = await _dio.get(
        ApiConstants.kpiEmployee(employeeId),
        queryParameters: {'year': year, 'month': month},
      );
      final data = res.data['data'];
      if (data is Map<String, dynamic>) return KpiEmployeeDetail.fromJson(data);
      return null;
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Total jam lembur disetujui pada bulan tertentu.
  Future<double> overtimeHours(int year, int month) async {
    try {
      final res = await _dio.get(
        ApiConstants.overtime,
        queryParameters: {
          'year': year,
          'month': month,
          'status': 'approved',
          'limit': 100,
        },
      );
      var total = 0.0;
      for (final item in res.data['data'] as List? ?? const []) {
        if (item is Map<String, dynamic>) {
          total += toNum(item['totalHours']).toDouble();
        }
      }
      return total;
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// 3 notifikasi terbaru untuk ringkasan di Beranda.
  Future<List<AppNotification>> latestNotifications() async {
    try {
      final res = await _dio.get(
        ApiConstants.notifications,
        queryParameters: {'limit': 3},
      );
      return (res.data['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Ringkasan absensi tim hari ini (hrd/spv) — `null` bila gagal / tidak berhak.
  Future<({int total, int checkedIn})?> teamToday() async {
    try {
      final res = await _dio.get(ApiConstants.attendanceToday);
      final data = res.data['data'];
      if (data is Map<String, dynamic>) {
        return (total: toInt(data['total']), checkedIn: toInt(data['checkedIn']));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Check-out absensi (tanpa token QR).
  Future<AttendanceRecord> checkOut(double lat, double lng) async {
    try {
      final res = await _dio.post(
        ApiConstants.checkOut,
        data: {'latitude': lat, 'longitude': lng},
      );
      return AttendanceRecord.fromJson(res.data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
