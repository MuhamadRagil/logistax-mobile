import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/office_location_model.dart';

/// Repository absensi — memakai [DioClient.instance]; setiap error
/// dibungkus menjadi [ApiException] agar siap ditampilkan ke user.
class AttendanceRepository {
  final _dio = DioClient.instance;

  /// GET /attendance/me/today → record saya hari ini atau null (belum absen).
  Future<AttendanceRecord?> myToday() async {
    try {
      final res = await _dio.get(ApiConstants.attendanceMeToday);
      final data = res.data['data'];
      if (data == null) return null;
      return AttendanceRecord.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /settings/attendance → titik kantor + radius GPS untuk tombol absensi.
  Future<AttendanceSettings> settings() async {
    try {
      final res = await _dio.get(ApiConstants.attendanceSettings);
      return AttendanceSettings.fromJson(
        (res.data['data'] as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /employees/:id/locations → lokasi aktif yang di-assign ke karyawan.
  /// Backend mengembalikan record assignment dengan `officeLocation` bersarang.
  Future<List<OfficeLocation>> employeeLocations(String employeeId) async {
    try {
      final res = await _dio.get(ApiConstants.employeeLocations(employeeId));
      final items = res.data['data'] as List? ?? const [];
      return items
          .whereType<Map>()
          .map((item) => (item['officeLocation'] ?? item) as Map)
          .where((loc) => loc['isActive'] != false)
          .map((loc) => OfficeLocation.fromJson(loc.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /attendance/check-in {latitude, longitude} → raw record map.
  /// Validasi murni GPS (haversine di server), tanpa token QR.
  Future<Map<String, dynamic>> checkIn(double lat, double lng) async {
    try {
      final res = await _dio.post(ApiConstants.checkIn, data: {
        'latitude': lat,
        'longitude': lng,
      });
      return (res.data['data'] as Map).cast<String, dynamic>();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /attendance/check-out {latitude, longitude, notes?} → raw record map.
  Future<Map<String, dynamic>> checkOut(double lat, double lng, {String? notes}) async {
    try {
      final res = await _dio.post(ApiConstants.checkOut, data: {
        'latitude': lat,
        'longitude': lng,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
      return (res.data['data'] as Map).cast<String, dynamic>();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /attendance/monthly?year=&month= → untuk role employee otomatis
  /// hanya diri sendiri (employees[0]). Kembalikan null bila kosong.
  Future<AttendanceMonthlyEmployee?> myMonthly(int year, int month) async {
    try {
      final res = await _dio.get(
        ApiConstants.attendanceMonthly,
        queryParameters: {'year': year, 'month': month},
      );
      final monthly = AttendanceMonthly.fromJson(res.data['data'] as Map<String, dynamic>);
      if (monthly.employees.isEmpty) return null;
      return monthly.employees.first;
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
