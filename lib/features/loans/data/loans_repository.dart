import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/loan_model.dart';

/// Repository pinjaman karyawan — memakai [DioClient.instance]; setiap error
/// dibungkus menjadi [ApiException] agar siap ditampilkan ke user.
class LoansRepository {
  final _dio = DioClient.instance;

  /// GET /loans/me → daftar pinjaman saya (aktif maupun lunas/dibatalkan).
  Future<List<EmployeeLoan>> myLoans() async {
    try {
      final res = await _dio.get(ApiConstants.myLoans);
      // Envelope bisa `{data: [...]}`, `{data: {items: [...]}}`, atau list langsung.
      final data = res.data is Map ? res.data['data'] : res.data;
      final list = data is List
          ? data
          : (data is Map && data['items'] is List ? data['items'] as List : const []);
      return list
          .whereType<Map>()
          .map((e) => EmployeeLoan.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
