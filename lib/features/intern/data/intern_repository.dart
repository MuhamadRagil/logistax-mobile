import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../intern_config.dart';
import '../models/intern_models.dart';
import 'intern_api_client.dart';

/// Akses API backend magang. Semua error dibungkus [ApiException] — pesan
/// `message` dari backend (mis. "Lokasi Anda di luar radius kantor…")
/// diteruskan apa adanya ke UI.
class InternRepository {
  Dio get _dio => InternApiClient.instance;

  /// POST /auth/intern/login → (token Sanctum, profil intern).
  Future<({String token, InternProfile profile})> login(String email, String password) async {
    try {
      final res = await _dio.post(InternEndpoints.login, data: {
        'email': email,
        'password': password,
      });
      final data = res.data is Map ? res.data['data'] : null;
      if (data is! Map || data['token'] is! String) {
        throw ApiException('Format respons login magang tidak sesuai');
      }
      final intern = data['intern'];
      if (intern is! Map) {
        throw ApiException(
          'Akun ini belum terhubung dengan data magang. Hubungi admin magang.',
        );
      }
      return (
        token: data['token'] as String,
        profile: InternProfile.fromJson(intern.cast<String, dynamic>()),
      );
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /auth/logout — mencabut token di server. Best-effort: sesi lokal
  /// tetap dihapus walau request gagal (mis. offline).
  Future<void> logout() async {
    try {
      await _dio.post(InternEndpoints.logout);
    } catch (_) {}
  }

  /// GET /attendance/my-history?month=&year=
  Future<List<InternAttendance>> myHistory({required int year, required int month}) async {
    try {
      final res = await _dio.get(
        InternEndpoints.myHistory,
        queryParameters: {'year': year, 'month': month},
      );
      return (res.data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => InternAttendance.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /attendance/check-in — koordinat mentah; radius divalidasi server.
  Future<String> checkIn(double latitude, double longitude) =>
      _postLocation(InternEndpoints.checkIn, latitude, longitude, 'Check-in berhasil.');

  /// POST /attendance/check-out — koordinat mentah; radius divalidasi server.
  Future<String> checkOut(double latitude, double longitude) =>
      _postLocation(InternEndpoints.checkOut, latitude, longitude, 'Check-out berhasil.');

  Future<String> _postLocation(String path, double lat, double lng, String fallback) async {
    try {
      final res = await _dio.post(path, data: {'latitude': lat, 'longitude': lng});
      final message = res.data is Map ? res.data['message'] : null;
      return message is String && message.isNotEmpty ? message : fallback;
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /attendance/leave-request (multipart). `proof_file` wajib untuk
  /// status "sakit" (jpg/jpeg/png/pdf, maks 5 MB) — divalidasi juga di form.
  Future<String> leaveRequest({
    required String date,
    required String status,
    String? notes,
    String? proofFilePath,
  }) async {
    try {
      final form = FormData.fromMap({
        'date': date,
        'status': status,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (proofFilePath != null)
          'proof_file': await MultipartFile.fromFile(proofFilePath),
      });
      final res = await _dio.post(InternEndpoints.leaveRequest, data: form);
      final message = res.data is Map ? res.data['message'] : null;
      return message is String && message.isNotEmpty
          ? message
          : 'Pengajuan berhasil dikirim, menunggu persetujuan.';
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /my-evaluation → null bila "Evaluasi belum tersedia." (bukan error).
  Future<InternEvaluation?> myEvaluation() async {
    try {
      final res = await _dio.get(InternEndpoints.myEvaluation);
      final data = res.data['data'];
      if (data is! Map) return null;
      return InternEvaluation.fromJson(data.cast<String, dynamic>());
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /my-certificate → null bila "Sertifikat belum tersedia." (bukan error).
  Future<InternCertificate?> myCertificate() async {
    try {
      final res = await _dio.get(InternEndpoints.myCertificate);
      final data = res.data['data'];
      if (data is! Map) return null;
      return InternCertificate.fromJson(data.cast<String, dynamic>());
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// GET /my-certificate/download → simpan PDF ke folder dokumen app, kembalikan
  /// path-nya. Pola sama dengan unduh slip gaji HR (sudah terbukti di production).
  Future<String> downloadCertificate(String nim) async {
    try {
      final res = await _dio.get<List<int>>(
        InternEndpoints.myCertificateDownload,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data ?? const <int>[];
      if (bytes.length < 4 || String.fromCharCodes(bytes.take(4)) != '%PDF') {
        throw ApiException('File sertifikat dari server tidak valid.');
      }
      final dir = await getApplicationDocumentsDirectory();
      final safeNim = nim.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      final path = '${dir.path}/Sertifikat-Magang-${safeNim.isEmpty ? 'saya' : safeNim}.pdf';
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } on DioException catch (e) {
      // Respons error diminta sebagai bytes → decode sendiri agar pesan
      // backend (mis. "Sertifikat belum tersedia.") tetap sampai ke user.
      final data = e.response?.data;
      if (data is List<int>) {
        try {
          final decoded = jsonDecode(utf8.decode(data));
          if (decoded is Map && decoded['message'] is String) {
            throw ApiException(decoded['message'] as String, statusCode: e.response?.statusCode);
          }
        } on FormatException {
          // bukan JSON — jatuh ke pesan generik di bawah
        }
      }
      throw ApiException.fromDio(e);
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
