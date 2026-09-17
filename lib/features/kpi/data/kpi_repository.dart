import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/kpi_model.dart';

/// Akses data KPI: detail milik sendiri + leaderboard bulanan.
class KpiRepository {
  final _dio = DioClient.instance;

  /// GET /kpi/employee/:employeeId?year=&month=
  /// Boleh diakses untuk data milik sendiri.
  Future<KpiEmployeeDetail> myKpi(String employeeId, int year, int month) async {
    try {
      final res = await _dio.get(
        ApiConstants.kpiEmployee(employeeId),
        queryParameters: {'year': year, 'month': month},
      );
      return KpiEmployeeDetail.fromJson(res.data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /kpi/monthly?year=&month=
  /// Untuk role employee backend MENOLAK sebelum periode difinalisasi —
  /// error sengaja dilempar agar halaman menampilkan status "belum tersedia".
  Future<KpiMonthly> monthly(int year, int month) async {
    try {
      final res = await _dio.get(
        ApiConstants.kpiMonthly,
        queryParameters: {'year': year, 'month': month},
      );
      return KpiMonthly.fromJson(res.data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
