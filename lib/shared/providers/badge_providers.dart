import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/leave_model.dart';

/// Jumlah notifikasi belum dibaca — badge lonceng di AppBar.
final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await DioClient.instance.get(ApiConstants.notificationsUnreadCount);
  final data = res.data['data'];
  if (data is Map && data['unread'] is num) return (data['unread'] as num).toInt();
  return 0;
});

/// Pengajuan cuti saya yang masih pending — badge di tab Cuti.
final myPendingLeaveCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await DioClient.instance.get(ApiConstants.myLeaveRequests);
  final list = (res.data['data'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(LeaveRequest.fromJson);
  return list.where((r) => r.status == 'pending').length;
});
