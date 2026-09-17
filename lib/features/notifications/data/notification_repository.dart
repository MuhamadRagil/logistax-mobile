import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/notification_model.dart';

/// Repository notifikasi — memakai [DioClient.instance]; setiap error
/// dibungkus menjadi [ApiException] agar siap ditampilkan ke user.
class NotificationRepository {
  final _dio = DioClient.instance;

  /// GET /notifications?page=&limit=&unreadOnly=true → daftar notifikasi saya.
  /// Parameter `unreadOnly` hanya dikirim bila bernilai true.
  Future<List<AppNotification>> list({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final res = await _dio.get(
        ApiConstants.notifications,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (unreadOnly) 'unreadOnly': 'true',
        },
      );
      final data = res.data['data'] as List? ?? const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// PATCH /notifications/:id/read → tandai satu notifikasi sudah dibaca.
  Future<void> markRead(String id) async {
    try {
      await _dio.patch(ApiConstants.notificationRead(id));
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// PATCH /notifications/read-all → tandai semua notifikasi sudah dibaca.
  Future<void> markAllRead() async {
    try {
      await _dio.patch(ApiConstants.notificationsReadAll);
    } catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
