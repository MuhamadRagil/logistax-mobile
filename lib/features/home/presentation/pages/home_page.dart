import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/attendance_model.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/kpi_tier_badge.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/logistax_app_bar.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/home_provider.dart';

/// Beranda: ringkasan absensi, cuti, KPI, lembur, notifikasi, dan tim.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final fullName = auth.user?.employee?.fullName ?? '';
    final firstName =
        fullName.trim().isEmpty ? 'Rekan' : fullName.trim().split(' ').first;

    return Scaffold(
      appBar: const LogistaxAppBar(title: 'Beranda'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeTodayProvider);
          ref.invalidate(homeBalancesProvider);
          ref.invalidate(homeKpiProvider);
          ref.invalidate(homeOvertimeProvider);
          ref.invalidate(homeNotificationsProvider);
          ref.invalidate(homeTeamTodayProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Greeting(firstName: firstName),
            const SizedBox(height: 16),
            const _StatusCard(),
            const SizedBox(height: 16),
            const _QuickStatsRow(),
            const SizedBox(height: 20),
            const _NotificationsSection(),
            if (auth.canSeeTeam) ...[
              const SizedBox(height: 20),
              const _TeamCard(),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Greeting ───────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  final String firstName;
  const _Greeting({required this.firstName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Halo, $firstName 👋',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          formatDateFull(DateTime.now()),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Card 1: Status Absensi ─────────────────────────────────────────────

class _StatusCard extends ConsumerWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(homeTodayProvider);
    return today.when(
      loading: () => const LoadingShimmer(count: 1, height: 150),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(homeTodayProvider),
      ),
      data: (record) => _buildContent(context, ref, record),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AttendanceRecord? record) {
    if (record == null) return const _BelumAbsenCard();

    const specialStatuses = {'cuti', 'sick', 'izin', 'holiday'};
    if (specialStatuses.contains(record.status)) {
      return _StatusInfoCard(status: record.status);
    }
    if (record.hasCheckedOut) return _CheckedOutCard(record: record);
    if (record.hasCheckedIn) return _CheckedInCard(record: record);
    return const _BelumAbsenCard();
  }
}

/// Belum absen: kartu gradient navy→teal + tombol scan.
class _BelumAbsenCard extends StatelessWidget {
  const _BelumAbsenCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.teal],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.access_time_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Status Absensi',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum Absen Hari Ini',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/absensi/scan?tujuan=checkin'),
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Absen Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sudah check-in, belum check-out.
class _CheckedInCard extends ConsumerStatefulWidget {
  final AttendanceRecord record;
  const _CheckedInCard({required this.record});

  @override
  ConsumerState<_CheckedInCard> createState() => _CheckedInCardState();
}

class _CheckedInCardState extends ConsumerState<_CheckedInCard> {
  bool _loading = false;

  Future<void> _handleCheckOut() async {
    // Cek & minta izin lokasi.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _snack('Izin lokasi diperlukan untuk check-out.', AppColors.error);
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check-out sekarang?'),
        content: const Text('Anda akan menyelesaikan absensi hari ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Check-out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      await ref
          .read(homeRepositoryProvider)
          .checkOut(position.latitude, position.longitude);
      if (!mounted) return;
      _snack('Check-out berhasil.', AppColors.success);
      ref.invalidate(homeTodayProvider);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final statusColor = AppColors.attendanceStatus(record.status);
    final baseLabel = AppStrings.attendanceStatusLabel[record.status] ?? 'Hadir';
    final badgeLabel = record.status == 'late' && record.lateMinutes > 0
        ? '$baseLabel ${record.lateMinutes} mnt'
        : baseLabel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TimeInfo(label: 'Jam Masuk', time: formatTimeWib(record.checkInTime)),
                StatusBadge(label: badgeLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Check-Out',
                icon: Icons.logout_rounded,
                loading: _loading,
                onPressed: _handleCheckOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sudah check-out.
class _CheckedOutCard extends StatelessWidget {
  final AttendanceRecord record;
  const _CheckedOutCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Absensi Hari Ini',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                StatusBadge(label: 'Selesai', color: AppColors.teal),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeInfo(
                    label: 'Jam Masuk',
                    time: formatTimeWib(record.checkInTime),
                  ),
                ),
                Expanded(
                  child: _TimeInfo(
                    label: 'Jam Keluar',
                    time: formatTimeWib(record.checkOutTime),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Status khusus (cuti/sakit/izin/libur).
class _StatusInfoCard extends StatelessWidget {
  final String status;
  const _StatusInfoCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.attendanceStatus(status);
    final label = AppStrings.attendanceStatusLabel[status] ?? status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.event_available_rounded, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(label: label, color: color),
                  const SizedBox(height: 6),
                  Text('Anda sedang $label hari ini'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  final String label;
  final String time;
  const _TimeInfo({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ── Row 3 kartu kecil ──────────────────────────────────────────────────

class _QuickStatsRow extends ConsumerWidget {
  const _QuickStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(homeBalancesProvider);
    final kpi = ref.watch(homeKpiProvider);
    final overtime = ref.watch(homeOvertimeProvider);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SmallCard(
              icon: Icons.beach_access_rounded,
              iconColor: AppColors.leave,
              title: 'Saldo Cuti',
              onTap: () => context.go('/cuti'),
              child: balances.when(
                loading: () => const _SmallLoading(),
                error: (_, _) => const _SmallValue(value: '-'),
                data: (list) {
                  if (list.isEmpty) {
                    return const _SmallValue(value: '-', caption: 'hari tersisa');
                  }
                  // Tampilkan cuti tahunan saja — menjumlahkan semua jenis
                  // (termasuk melahirkan 90 hari) memberi angka yang menyesatkan.
                  final annual = list.where(
                    (b) => b.leaveTypeName.toLowerCase().contains('tahunan'),
                  );
                  final balance = annual.isNotEmpty ? annual.first : list.first;
                  return _SmallValue(
                    value: '${balance.remaining}',
                    caption: annual.isNotEmpty ? 'cuti tahunan' : 'hari tersisa',
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SmallCard(
              icon: Icons.emoji_events_rounded,
              iconColor: AppColors.warning,
              title: 'KPI Bulan Ini',
              onTap: () => context.push('/kpi'),
              child: kpi.when(
                loading: () => const _SmallLoading(),
                error: (_, _) => const _SmallValue(value: 'Belum tersedia', small: true),
                data: (detail) {
                  final summary = detail?.summary;
                  if (summary == null) {
                    return const _SmallValue(value: 'Belum tersedia', small: true);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.totalScore.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      KpiTierBadge(tier: summary.tier, fontSize: 10),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SmallCard(
              icon: Icons.schedule_rounded,
              iconColor: AppColors.info,
              title: 'Lembur',
              onTap: null,
              child: overtime.when(
                loading: () => const _SmallLoading(),
                error: (_, _) => const _SmallValue(value: '0', caption: 'jam'),
                data: (hours) => _SmallValue(
                  value: _formatHours(hours),
                  caption: 'jam bulan ini',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) return hours.toInt().toString();
    return hours.toStringAsFixed(1);
  }
}

class _SmallCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  const _SmallCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallValue extends StatelessWidget {
  final String value;
  final String? caption;
  final bool small;
  const _SmallValue({required this.value, this.caption, this.small = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: small
              ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
              : const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _SmallLoading extends StatelessWidget {
  const _SmallLoading();

  @override
  Widget build(BuildContext context) => const LoadingShimmer(count: 1, height: 34);
}

// ── Notifikasi Terbaru ─────────────────────────────────────────────────

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifications = ref.watch(homeNotificationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notifikasi Terbaru',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.push('/notifikasi'),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        notifications.when(
          loading: () => const LoadingShimmer(count: 3, height: 60),
          error: (_, _) => const EmptyState(
            icon: Icons.notifications_off_rounded,
            title: 'Gagal memuat notifikasi',
          ),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Belum ada notifikasi',
              );
            }
            return Column(
              children: [
                for (final n in list) _NotificationTile(notification: n),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _iconColor(notification.type);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(_iconFor(notification.type), color: color, size: 20),
      ),
      title: Text(
        notification.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        notification.message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _relativeTime(notification.createdAt),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      onTap: () => context.push('/notifikasi'),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'leave_approved':
      case 'leave_rejected':
      case 'leave_request':
        return Icons.beach_access_rounded;
      case 'payroll_ready':
        return Icons.receipt_long_rounded;
      case 'kpi_published':
        return Icons.emoji_events_rounded;
      case 'attendance':
        return Icons.access_time_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'leave_approved':
        return AppColors.success;
      case 'leave_rejected':
        return AppColors.error;
      case 'leave_request':
        return AppColors.leave;
      case 'payroll_ready':
        return AppColors.teal;
      case 'kpi_published':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }
}

// ── Kartu Tim (SPV/HRD) ────────────────────────────────────────────────

class _TeamCard extends ConsumerWidget {
  const _TeamCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final team = ref.watch(homeTeamTodayProvider);

    return team.when(
      loading: () => const LoadingShimmer(count: 1, height: 120),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final total = data.total;
        final checkedIn = data.checkedIn;
        final progress = total == 0 ? 0.0 : checkedIn / total;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: AppColors.navy),
                    const SizedBox(width: 8),
                    Text(
                      'Tim Anda Hari Ini',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$checkedIn dari $total sudah absen',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'Lihat Tim',
                    icon: Icons.arrow_forward_rounded,
                    outlined: true,
                    onPressed: () => context.go('/spv/tim'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Util waktu relatif ─────────────────────────────────────────────────

String _relativeTime(String? iso) {
  if (iso == null) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  final diff = DateTime.now().difference(date.toLocal());
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt';
  if (diff.inHours < 24) return '${diff.inHours} jam';
  if (diff.inDays < 7) return '${diff.inDays} hr';
  return formatDateShort(date);
}
