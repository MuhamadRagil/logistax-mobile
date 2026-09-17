import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/notification_model.dart';
import '../data/notification_repository.dart';

/// Repository notifikasi (single instance per lifecycle app).
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

/// Daftar notifikasi saya. Parameter family = `unreadOnly`
/// (false = semua, true = hanya yang belum dibaca).
final notificationsProvider =
    FutureProvider.autoDispose.family<List<AppNotification>, bool>((ref, unreadOnly) {
  return ref.watch(notificationRepositoryProvider).list(unreadOnly: unreadOnly);
});
