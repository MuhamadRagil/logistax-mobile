import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/providers/badge_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../providers/notification_provider.dart';

/// Ikon + warna per jenis notifikasi (dipakai juga di halaman detail).
({IconData icon, Color color}) notificationVisual(String type) {
  switch (type) {
    case 'leave_approved':
      return (icon: Icons.check_circle_rounded, color: AppColors.success);
    case 'leave_rejected':
      return (icon: Icons.cancel_rounded, color: AppColors.error);
    case 'payroll_ready':
      return (icon: Icons.receipt_long_rounded, color: AppColors.teal);
    case 'kpi_published':
      return (icon: Icons.insights_rounded, color: AppColors.warning);
    case 'leave_request':
      return (icon: Icons.inbox_rounded, color: AppColors.navy);
    default:
      return (icon: Icons.notifications_rounded, color: AppColors.holiday);
  }
}

/// Waktu relatif singkat: "Baru saja", "5 menit lalu", "3 jam lalu",
/// "2 hari lalu", selebihnya tanggal pendek.
String relativeTime(dynamic value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) return '-';
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return formatDateShort(value);
}

/// Daftar notifikasi saya dengan filter semua / belum dibaca.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _unreadOnly = false;
  bool _markingAll = false;

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      if (!mounted) return;
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua notifikasi ditandai sudah dibaca'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiException.fromDio(e).message),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _openDetail(AppNotification notification) {
    if (!notification.isRead) {
      // Fire & forget — UI tidak perlu menunggu.
      ref.read(notificationRepositoryProvider).markRead(notification.id).then((_) {
        if (!mounted) return;
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationsProvider);
      }).catchError((_) {
        // abaikan: gagal menandai tidak menghalangi membuka detail
      });
    }
    context.push('/notifikasi/detail', extra: notification);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider(_unreadOnly));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: _markingAll ? null : _markAllRead,
            child: const Text('Tandai Semua'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: !_unreadOnly,
                  onSelected: (_) => setState(() => _unreadOnly = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Belum Dibaca'),
                  selected: _unreadOnly,
                  onSelected: (_) => setState(() => _unreadOnly = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsProvider(_unreadOnly));
                ref.invalidate(unreadNotificationsProvider);
                await ref.read(notificationsProvider(_unreadOnly).future);
              },
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingShimmer(count: 6, height: 72),
                ),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                    ErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(notificationsProvider(_unreadOnly)),
                    ),
                  ],
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        EmptyState(
                          icon: Icons.notifications_off_rounded,
                          title: 'Belum ada notifikasi',
                          description: _unreadOnly
                              ? 'Semua notifikasi Anda sudah dibaca.'
                              : 'Notifikasi baru akan muncul di sini.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) => _NotificationTile(
                      notification: items[index],
                      onTap: () => _openDetail(items[index]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = notificationVisual(notification.type);
    final unread = !notification.isRead;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: visual.color.withValues(alpha: 0.14),
        child: Icon(visual.icon, color: visual.color, size: 22),
      ),
      title: Text(
        notification.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: unread ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          notification.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            relativeTime(notification.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (unread)
            Container(
              height: 9,
              width: 9,
              decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
            )
          else
            const SizedBox(height: 9),
        ],
      ),
    );
  }
}
