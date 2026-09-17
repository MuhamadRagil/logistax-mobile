import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/employee_model.dart';
import '../../../shared/models/leave_model.dart';

/// Akses data tim untuk supervisor: papan absensi hari ini, anggota tim,
/// dan persetujuan pengajuan cuti bawahan.
class SpvRepository {
  final _dio = DioClient.instance;

  /// GET /attendance/today (hrd/spv) → daftar absensi semua karyawan hari ini.
  Future<List<TodayBoardItem>> todayBoard() async {
    try {
      final res = await _dio.get(ApiConstants.attendanceToday);
      final employees = res.data['data']?['employees'] as List? ?? const [];
      return employees
          .whereType<Map<String, dynamic>>()
          .map(TodayBoardItem.fromJson)
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /employees?limit=100 (hrd/spv) → dipakai untuk memfilter bawahan.
  Future<List<TeamMember>> teamMembers() async {
    try {
      final res = await _dio.get(
        ApiConstants.employees,
        queryParameters: {'limit': 100},
      );
      return (res.data['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TeamMember.fromJson)
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /leave/requests?status=pending&limit=50 — backend otomatis membatasi
  /// SPV hanya ke pengajuan bawahannya.
  Future<List<LeaveRequest>> pendingLeaves() async {
    try {
      final res = await _dio.get(
        ApiConstants.leaveRequests,
        queryParameters: {'status': 'pending', 'limit': 50},
      );
      return (res.data['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LeaveRequest.fromJson)
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// PATCH /leave/requests/:id/review — setujui atau tolak pengajuan cuti.
  Future<void> review(
    String id, {
    required bool approve,
    String? rejectionReason,
  }) async {
    try {
      await _dio.patch(ApiConstants.leaveReview(id), data: {
        'status': approve ? 'approved' : 'rejected',
        'rejectionReason': ?rejectionReason,
      });
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
