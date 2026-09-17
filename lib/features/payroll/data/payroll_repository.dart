import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/payslip_model.dart';

/// Repository slip gaji — memakai [DioClient.instance]; setiap error
/// dibungkus menjadi [ApiException] agar siap ditampilkan ke user.
class PayrollRepository {
  final _dio = DioClient.instance;

  /// GET /payroll/employee/:employeeId → daftar slip gaji saya.
  Future<List<Payslip>> mySlips(String employeeId) async {
    try {
      final res = await _dio.get(ApiConstants.myPayslips(employeeId));
      return _asList(res.data)
          .whereType<Map>()
          .map((e) => Payslip.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /payroll/slips/:id → detail satu slip gaji.
  Future<Payslip> slip(String id) async {
    try {
      final res = await _dio.get(ApiConstants.slip(id));
      final data = res.data is Map ? res.data['data'] : res.data;
      return Payslip.fromJson((data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /payroll/slips/:id/pdf → PDF biner, disimpan ke direktori dokumen
  /// aplikasi. Mengembalikan path file yang tersimpan (untuk dibuka/dibagikan).
  /// PDF terkunci password: 6 digit terakhir NIK (`slip.pdfPasswordHint`).
  Future<String> downloadPdf(String slipId, String filename) async {
    try {
      final res = await _dio.get<List<int>>(
        ApiConstants.slipPdf(slipId),
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/$filename';
      await File(path).writeAsBytes(res.data ?? const <int>[], flush: true);
      return path;
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Envelope backend bisa `{data: [...]}`, `{data: {items: [...]}}`,
  /// atau langsung sebuah list.
  List _asList(dynamic body) {
    final data = body is Map ? body['data'] : body;
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'] as List;
    return const [];
  }
}
