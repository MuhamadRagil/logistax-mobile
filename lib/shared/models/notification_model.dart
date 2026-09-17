import 'model_utils.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    this.relatedEntityType,
    this.relatedEntityId,
    this.createdAt,
  });

  /// Route tujuan saat notifikasi di-tap.
  String get targetRoute {
    switch (type) {
      case 'leave_approved':
      case 'leave_rejected':
        return '/cuti/riwayat';
      case 'leave_request':
        return '/spv/tim';
      case 'payroll_ready':
        return '/slip';
      case 'kpi_published':
        return '/kpi';
      default:
        return '/notifikasi';
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: toStr(json['type']) ?? 'system',
        title: toStr(json['title']) ?? '',
        message: toStr(json['message']) ?? '',
        isRead: json['isRead'] == true,
        relatedEntityType: toStr(json['relatedEntityType']),
        relatedEntityId: toStr(json['relatedEntityId']),
        createdAt: toStr(json['createdAt']),
      );
}
