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

  /// PATCH /employees/me/profile {phone, address} — hanya field milik sendiri
  /// yang boleh diubah karyawan; nama/NIK/jabatan tetap wewenang HRD.
  Future<EmployeeProfile> updateMyProfile({required String phone, required String address}) async {
    try {
      final res = await _dio.patch(ApiConstants.employeeMeProfile, data: {
        'phone': phone,
        'address': address,
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
