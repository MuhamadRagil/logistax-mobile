import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/widgets/app_button.dart';
import 'notifications_page.dart' show notificationVisual;

/// Detail satu notifikasi + tombol menuju halaman terkait.
class NotificationDetailPage extends ConsumerWidget {
  const NotificationDetailPage({super.key, required this.notification});

  final AppNotification notification;

  /// Label tombol aksi sesuai jenis notifikasi. null = tombol disembunyikan.
  String? get _actionLabel {
    switch (notification.type) {
      case 'leave_approved':
      case 'leave_rejected':
        return 'Lihat Riwayat Cuti';
      case 'payroll_ready':
        return 'Lihat Slip Gaji';
      case 'kpi_published':
        return 'Lihat KPI Saya';
      case 'leave_request':
        return 'Lihat Pengajuan Tim';
      default:
        return null;
    }
  }

  void _goToTarget(BuildContext context) {
    final route = notification.targetRoute;
    // /cuti/riwayat dan /spv/tim berada di dalam shell (tab) → pakai go.
    if (route == '/cuti/riwayat' || route == '/spv/tim') {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final visual = notificationVisual(notification.type);
    final label = _actionLabel;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Notifikasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: visual.color.withValues(alpha: 0.14),
                        child: Icon(visual.icon, color: visual.color, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${formatDateFull(notification.createdAt)} • '
                          '${formatTime(notification.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: label,
                icon: Icons.arrow_forward_rounded,
                onPressed: () => _goToTarget(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
