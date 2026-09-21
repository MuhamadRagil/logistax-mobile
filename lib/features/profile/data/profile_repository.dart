import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/employee_model.dart';

/// Repository profil — baca + update data milik sendiri.
class ProfileRepository {
  final _dio = DioClient.instance;

  /// GET /users/me → data.employee (null bila akun tidak terhubung karyawan).
  Future<EmployeeProfile?> myProfile() async {
    try {
      final res = await _dio.get(ApiConstants.me);
      final data = res.data['data'];
      if (data is! Map) return null;
      final employee = data['employee'];
      if (employee is! Map) return null;
      return EmployeeProfile.fromJson(employee.cast<String, dynamic>());
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// PATCH /employees/me/profile — field milik sendiri yang boleh diubah
  /// karyawan; NIK/jabatan/departemen/status/tanggal masuk tetap wewenang HRD.
  /// `birthDate` (format "yyyy-MM-dd") dikirim hanya bila terisi — mengirim
  /// null akan gagal validasi (`@IsDateString`) di backend.
  Future<EmployeeProfile> updateMyProfile({
    required String fullName,
    required String phone,
    required String address,
    String? gender,
    String? birthDate,
    required String bankName,
    required String bankAccountNumber,
    required String npwp,
    required String bpjsKesehatan,
    required String bpjsTk,
  }) async {
    try {
      final res = await _dio.patch(ApiConstants.employeeMeProfile, data: {
        'fullName': fullName,
        'phone': phone,
        'address': address,
        if (gender != null) 'gender': gender, // 'male' | 'female'
        if (birthDate != null) 'birthDate': birthDate,
        'bankName': bankName,
        'bankAccountNumber': bankAccountNumber,
        'npwp': npwp,
        'bpjsKesehatan': bpjsKesehatan,
        'bpjsTk': bpjsTk,
      });
      return EmployeeProfile.fromJson((res.data['data'] as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// PATCH /employees/me/photo (multipart, field 'file') → profil dengan photoUrl baru.
  Future<EmployeeProfile> uploadMyPhoto(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final res = await _dio.patch(ApiConstants.employeeMePhoto, data: formData);
      return EmployeeProfile.fromJson((res.data['data'] as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
