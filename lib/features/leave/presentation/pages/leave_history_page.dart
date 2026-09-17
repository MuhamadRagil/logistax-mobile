import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/leave_model.dart';
import '../../../../shared/providers/badge_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../providers/leave_provider.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return AppColors.warning;
    case 'approved':
      return AppColors.success;
    case 'rejected':
      return AppColors.error;
    default:
      return AppColors.holiday;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'pending':
      return Icons.hourglass_empty_rounded;
    case 'approved':
      return Icons.check_circle_rounded;
    case 'rejected':
      return Icons.cancel_rounded;
    default:
      return Icons.block_rounded;
  }
}

String _statusLabel(String status) => AppStrings.leaveStatusLabel[status] ?? status;

/// Riwayat pengajuan cuti saya, dikelompokkan per status.
class LeaveHistoryPage extends ConsumerWidget {
  const LeaveHistoryPage({super.key});

  static const _tabs = ['Semua', 'Menunggu', 'Disetujui', 'Ditolak'];
  static const _filters = [null, 'pending', 'approved', 'rejected'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myLeaveRequestsProvider);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat Cuti'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            // AppBar berlatar navy — paksa label putih agar terbaca.
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.teal,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Menunggu'),
              Tab(text: 'Disetujui'),
              Tab(text: 'Ditolak'),
            ],
          ),
        ),
        body: requestsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(count: 5),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(myLeaveRequestsProvider),
          ),
          data: (all) => TabBarView(
            children: List.generate(_tabs.length, (i) {
              final filter = _filters[i];
              final list =
                  filter == null ? all : all.where((r) => r.status == filter).toList();
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(myLeaveRequestsProvider),
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.event_busy_outlined,
                            title: filter == null
                                ? 'Belum ada pengajuan cuti'
                                : 'Tidak ada pengajuan ${_tabs[i].toLowerCase()}',
                            description: filter == null
                                ? 'Pengajuan cuti Anda akan tampil di sini.'
                                : null,
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (_, index) {
                          final r = list[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: CircleAvatar(
                                backgroundColor:
                                    _statusColor(r.status).withValues(alpha: 0.14),
                                child: Icon(
                                  _statusIcon(r.status),
                                  color: _statusColor(r.status),
                                ),
                              ),
                              title: Text(
                                r.leaveTypeName ?? 'Cuti',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${formatDateShort(r.startDate)} – '
                                '${formatDateShort(r.endDate)} • ${r.totalDays} hari',
                              ),
                              trailing: StatusBadge(
                                label: _statusLabel(r.status),
                                color: _statusColor(r.status),
                              ),
                              onTap: () => _showDetailSheet(context, ref, r),
                            ),
                          );
                        },
                      ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext pageContext, WidgetRef ref, LeaveRequest r) {
    showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.leaveTypeName ?? 'Cuti',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    StatusBadge(
                      label: _statusLabel(r.status),
                      color: _statusColor(r.status),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  label: 'Tanggal',
                  value: '${formatDateLong(r.startDate)} – ${formatDateLong(r.endDate)}',
                ),
                const SizedBox(height: 10),
                _DetailRow(label: 'Total Hari', value: '${r.totalDays} hari'),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Alasan',
                  value: r.reason.isEmpty ? '-' : r.reason,
                ),
                if (r.documentUrl != null) ...[
                  const SizedBox(height: 10),
                  _DetailRow(label: 'Dokumen', value: r.documentUrl!),
                ],
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Diajukan',
                  value: r.createdAt == null ? '-' : formatDateLong(r.createdAt),
                ),
                if (r.status == 'rejected' && (r.rejectionReason?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Alasan Penolakan',
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(r.rejectionReason!, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
                if (r.status == 'pending') ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      onPressed: () => _cancel(pageContext, sheetCtx, ref, r),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Batalkan Pengajuan'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancel(
    BuildContext pageContext,
    BuildContext sheetContext,
    WidgetRef ref,
    LeaveRequest r,
  ) async {
    final messenger = ScaffoldMessenger.of(pageContext);
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Batalkan Pengajuan?'),
        content: const Text(
          'Pengajuan cuti ini akan dibatalkan dan tidak dapat dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(leaveRepositoryProvider).cancel(r.id);
      ref.invalidate(myLeaveRequestsProvider);
      ref.invalidate(myBalancesProvider);
      ref.invalidate(myPendingLeaveCountProvider);

      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pengajuan cuti berhasil dibatalkan'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ApiException.fromDio(e).message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
