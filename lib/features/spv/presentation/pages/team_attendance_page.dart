import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/attendance_model.dart';
import '../../../../shared/models/leave_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/logistax_app_bar.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../providers/spv_provider.dart';

/// Status absensi yang dikenal backend. Di luar ini (atau null) = belum absen.
const _knownStatuses = {
  'present',
  'late',
  'absent',
  'sick',
  'izin',
  'cuti',
  'wfh',
  'holiday',
};

bool _belumAbsen(TodayBoardItem item) =>
    item.status == null || !_knownStatuses.contains(item.status);

String _statusLabel(TodayBoardItem item) =>
    AppStrings.attendanceStatusLabel[item.status] ?? 'Belum Absen';

/// Inisial dari nama lengkap (maks 2 huruf) untuk fallback foto.
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts[1].characters.first).toUpperCase();
}

/// Halaman tim supervisor: absensi tim hari ini + persetujuan cuti bawahan.
class TeamAttendancePage extends ConsumerStatefulWidget {
  const TeamAttendancePage({super.key});

  @override
  ConsumerState<TeamAttendancePage> createState() => _TeamAttendancePageState();
}

class _TeamAttendancePageState extends ConsumerState<TeamAttendancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingLeavesProvider).value?.length ?? 0;

    return Scaffold(
      appBar: LogistaxAppBar(
        title: 'Tim Saya',
        bottom: TabBar(
          controller: _tabController,
          // AppBar berlatar navy — paksa label putih agar terbaca.
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.teal,
          indicatorWeight: 3,
          tabs: [
            const Tab(text: 'Hari Ini'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cuti Pending'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_TodayTab(), _PendingLeavesTab()],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 1 — Hari Ini
// ─────────────────────────────────────────────────────────────

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(teamTodayProvider);

    return boardAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingShimmer(count: 4),
      ),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(teamTodayProvider),
      ),
      data: (board) {
        final hadir = board.where((i) => i.status == 'present').length;
        final terlambat = board.where((i) => i.status == 'late').length;
        final belumAbsen = board.where(_belumAbsen).length;
        final lainnya = board.length - hadir - terlambat - belumAbsen;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(teamTodayProvider),
          child: board.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Belum ada anggota tim',
                      description: 'Anggota tim Anda akan tampil di sini.',
                    ),
                  ],
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      sliver: SliverToBoxAdapter(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SummaryChip(
                              label: 'Hadir',
                              count: hadir,
                              color: AppColors.present,
                            ),
                            _SummaryChip(
                              label: 'Terlambat',
                              count: terlambat,
                              color: AppColors.late,
                            ),
                            _SummaryChip(
                              label: 'Belum Absen',
                              count: belumAbsen,
                              color: AppColors.holiday,
                            ),
                            _SummaryChip(
                              label: 'Cuti/Lainnya',
                              count: lainnya,
                              color: AppColors.leave,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.95,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, index) => _MemberCard(item: board[index]),
                          childCount: board.length,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final TodayBoardItem item;

  const _MemberCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.attendanceStatus(item.status);
    final photo = item.photoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final checkIn = item.record?.checkInTime;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.16),
            backgroundImage: hasPhoto ? CachedNetworkImageProvider(photo) : null,
            child: hasPhoto
                ? null
                : Text(
                    _initials(item.fullName),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              item.fullName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
          ),
          if (item.positionName != null) ...[
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                item.positionName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          StatusBadge(label: _statusLabel(item), color: color, fontSize: 10),
          if (checkIn != null) ...[
            const SizedBox(height: 4),
            Text(
              formatTime(checkIn),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 2 — Cuti Pending
// ─────────────────────────────────────────────────────────────

class _PendingLeavesTab extends ConsumerStatefulWidget {
  const _PendingLeavesTab();

  @override
  ConsumerState<_PendingLeavesTab> createState() => _PendingLeavesTabState();
}

class _PendingLeavesTabState extends ConsumerState<_PendingLeavesTab> {
  /// Id pengajuan yang sedang diproses — menonaktifkan tombol pada kartu itu.
  final Set<String> _reviewing = {};

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingLeavesProvider);

    return pendingAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingShimmer(count: 3, height: 190),
      ),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(pendingLeavesProvider),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingLeavesProvider),
        child: list.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Tidak ada pengajuan menunggu persetujuan',
                    description: 'Semua pengajuan cuti tim sudah diproses.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, index) {
                  final r = list[index];
                  return _LeaveRequestCard(
                    request: r,
                    busy: _reviewing.contains(r.id),
                    onApprove: () => _approve(r),
                    onReject: () => _reject(r),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _approve(LeaveRequest r) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Setujui Pengajuan?'),
        content: Text(
          'Pengajuan cuti ${r.employeeName ?? 'karyawan ini'} '
          '(${formatDateLong(r.startDate)} – ${formatDateLong(r.endDate)}) '
          'akan disetujui.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _submitReview(
      messenger,
      r,
      approve: true,
      successMessage: 'Pengajuan cuti disetujui',
    );
  }

  Future<void> _reject(LeaveRequest r) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Tolak Pengajuan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Berikan alasan penolakan untuk '
                  '${r.employeeName ?? 'karyawan ini'}.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Alasan penolakan',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Batal'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    setDialogState(() => errorText = 'Alasan penolakan wajib diisi');
                    return;
                  }
                  Navigator.of(dialogCtx).pop(text);
                },
                child: const Text('Tolak'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;

    await _submitReview(
      messenger,
      r,
      approve: false,
      rejectionReason: reason,
      successMessage: 'Pengajuan cuti ditolak',
    );
  }

  Future<void> _submitReview(
    ScaffoldMessengerState messenger,
    LeaveRequest r, {
    required bool approve,
    String? rejectionReason,
    required String successMessage,
  }) async {
    setState(() => _reviewing.add(r.id));
    try {
      await ref.read(spvRepositoryProvider).review(
            r.id,
            approve: approve,
            rejectionReason: rejectionReason,
          );
      ref.invalidate(pendingLeavesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: AppColors.success),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ApiException.fromDio(e).message),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _reviewing.remove(r.id));
    }
  }
}

class _LeaveRequestCard extends StatelessWidget {
  final LeaveRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _LeaveRequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.employeeName ?? 'Karyawan',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (r.departmentName != null)
                        Text(
                          r.departmentName!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  label: r.leaveTypeName ?? 'Cuti',
                  color: AppColors.info,
                  fontSize: 11,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${formatDateLong(r.startDate)} – ${formatDateLong(r.endDate)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                '${r.totalDays} hari kerja',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (r.reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '"${r.reason}"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (r.createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Diajukan ${formatDateLong(r.createdAt)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Setujui',
                    icon: Icons.check_rounded,
                    color: AppColors.success,
                    loading: busy,
                    onPressed: busy ? null : onApprove,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('Tolak'),
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
