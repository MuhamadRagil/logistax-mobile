import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/leave_model.dart';
import '../../../shared/models/model_utils.dart';

/// Akses data cuti/izin (jenis, saldo, pengajuan) ke backend.
class LeaveRepository {
  final _dio = DioClient.instance;

  /// GET /leave/types
  Future<List<LeaveType>> types() async {
    try {
      final res = await _dio.get(ApiConstants.leaveTypes);
      return (res.data['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LeaveType.fromJson)
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /leave/balances/me?year=
  Future<List<LeaveBalance>> myBalances(int year) async {
    try {
      final res = await _dio.get(
        ApiConstants.leaveBalancesMe,
        queryParameters: {'year': year},
      );
      return (res.data['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LeaveBalance.fromJson)
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /leave/requests/my
  Future<List<LeaveRequest>> myRequests() async {
    try {
      final res = await _dio.get(ApiConstants.myLeaveRequests);
      return (res.data['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LeaveRequest.fromJson)
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /leave/requests.
  Future<LeaveRequest> submit({
    required String leaveTypeId,
    required String startDate,
    required String endDate,
    required String reason,
    String? documentUrl,
  }) async {
    try {
      final res = await _dio.post(ApiConstants.leaveRequests, data: {
        'leaveTypeId': leaveTypeId,
        'startDate': startDate,
        'endDate': endDate,
        'reason': reason,
        if (documentUrl != null) 'documentUrl': documentUrl,
      });
      return LeaveRequest.fromJson(res.data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Upload foto pendukung (mis. surat dokter) → URL Cloudinary.
  /// Null bila endpoint belum tersedia / Cloudinary belum dikonfigurasi di
  /// server — pemanggil diharapkan lanjut kirim laporan tanpa documentUrl.
  Future<String?> uploadDocument(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final res = await _dio.post(ApiConstants.leaveDocumentUpload, data: formData);
      return toStr((res.data['data'] as Map)['url']);
    } catch (_) {
      return null;
    }
  }

  /// PATCH /leave/requests/:id/cancel
  Future<void> cancel(String id) async {
    try {
      await _dio.patch(ApiConstants.leaveCancel(id));
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
