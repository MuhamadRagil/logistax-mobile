import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../models/intern_models.dart';
import '../../providers/intern_providers.dart';
import '../../providers/intern_session.dart';

/// Beranda intern: status magang, sisa hari, dan status absensi hari ini.
class InternHomePage extends ConsumerWidget {
  const InternHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(internSessionProvider).profile;
    final today = ref.watch(internTodayProvider);
    final theme = Theme.of(context);

    if (profile == null) return const Scaffold();
    final remaining = profile.remainingDays(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Beranda Magang')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(internTodayProvider);
          await ref.read(internTodayProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.navy, AppColors.teal],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${profile.fullName.isEmpty ? 'Intern' : profile.fullName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [profile.nim, profile.institution]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Pill(label: profile.statusLabel),
                      const Spacer(),
                      if (remaining != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$remaining hari',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'sisa masa magang',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (profile.startDate != null && profile.endDate != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Periode: ${formatDateShort(profile.startDate)} – ${formatDateShort(profile.endDate)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Absensi Hari Ini',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            today.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: ErrorState(error: e, onRetry: () => ref.invalidate(internTodayProvider)),
              ),
              data: (record) => _TodayCard(record: record, canAttend: profile.canAttend),
            ),
            const SizedBox(height: 20),
            Text(
              'Menu Cepat',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                _Shortcut(
                  icon: Icons.fingerprint,
                  label: 'Absensi GPS',
                  onTap: () => context.go('/intern/absensi'),
                ),
                _Shortcut(
                  icon: Icons.event_note_rounded,
                  label: 'Ajukan Izin/Sakit',
                  onTap: () => context.go('/intern/izin'),
                ),
                _Shortcut(
                  icon: Icons.grade_rounded,
                  label: 'Nilai Saya',
                  onTap: () => context.go('/intern/nilai'),
                ),
                _Shortcut(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Sertifikat',
                  onTap: () => context.push('/intern/sertifikat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.record, required this.canAttend});

  final InternAttendance? record;
  final bool canAttend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = record;

    late final String title;
    late final String subtitle;
    late final Color color;
    late final IconData icon;

    if (r == null) {
      title = 'Belum check-in';
      subtitle = canAttend
          ? 'Buka tab Absensi untuk check-in dengan GPS.'
          : 'Absensi tersedia saat status magang Anda aktif.';
      color = AppColors.holiday;
      icon = Icons.fingerprint_rounded;
    } else if (r.isLeave) {
      title = 'Pengajuan ${r.statusLabel}';
      subtitle = internApprovalLabel[r.approvalStatus] ?? 'Menunggu persetujuan';
      color = AppColors.leave;
      icon = Icons.event_note_rounded;
    } else if (r.hasCheckedOut) {
      title = 'Selesai hari ini';
      subtitle = 'Masuk ${formatTime(r.checkInTime)} • Pulang ${formatTime(r.checkOutTime)}';
      color = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (r.hasCheckedIn) {
      title = 'Sudah check-in';
      subtitle = 'Masuk ${formatTime(r.checkInTime)} • belum check-out';
      color = AppColors.teal;
      icon = Icons.login_rounded;
    } else {
      title = r.statusLabel;
      subtitle = '-';
      color = AppColors.holiday;
      icon = Icons.info_outline_rounded;
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
