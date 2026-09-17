import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/providers/badge_providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../providers/leave_provider.dart';

/// Indikator langkah form cuti (3 lingkaran + garis). Disalin ke tiap halaman form.
class _StepIndicator extends StatelessWidget {
  final int current; // 1..3
  const _StepIndicator(this.current);

  static const _labels = ['Detail', 'Alasan', 'Konfirmasi'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (var step = 1; step <= 3; step++) {
      final active = step <= current;
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor:
                  active ? AppColors.teal : theme.colorScheme.surfaceContainerHighest,
              child: active && step < current
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        color: active ? Colors.white : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              _labels[step - 1],
              style: theme.textTheme.labelSmall?.copyWith(
                color: active ? AppColors.teal : theme.colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
      if (step < 3) {
        children.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: step < current
                  ? AppColors.teal
                  : theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// Langkah 3: ringkasan & kirim pengajuan.
class LeaveConfirmPage extends ConsumerStatefulWidget {
  const LeaveConfirmPage({super.key});

  @override
  ConsumerState<LeaveConfirmPage> createState() => _LeaveConfirmPageState();
}

class _LeaveConfirmPageState extends ConsumerState<LeaveConfirmPage> {
  bool _loading = false;

  Future<void> _submit() async {
    final draft = ref.read(leaveDraftProvider);
    if (draft.leaveTypeId == null || !draft.hasDates) return;

    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(leaveRepositoryProvider).submit(
            leaveTypeId: draft.leaveTypeId!,
            startDate: toApiDate(draft.startDate!),
            endDate: toApiDate(draft.endDate!),
            reason: draft.reason,
          );

      ref.invalidate(myLeaveRequestsProvider);
      ref.invalidate(myBalancesProvider);
      ref.invalidate(myPendingLeaveCountProvider);

      if (!mounted) return;
      setState(() => _loading = false);
      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(ApiException.fromDio(e).message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.tealLight,
              child: Icon(Icons.check_rounded, size: 36, color: AppColors.teal),
            ),
            const SizedBox(height: 16),
            Text(
              'Pengajuan Terkirim!',
              style: Theme.of(dialogCtx).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pengajuan cuti Anda menunggu persetujuan atasan.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              // Reset setelah dialog ditutup agar ringkasan tidak berkedip.
              resetLeaveDraft(ref);
              context.go('/cuti/riwayat');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = ref.watch(leaveDraftProvider);
    final days = draft.hasDates ? countWorkingDays(draft.startDate!, draft.endDate!) : 0;
    final complete = draft.leaveTypeId != null && draft.hasDates;

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Pengajuan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _StepIndicator(3),
          const SizedBox(height: 16),
          if (!complete)
            Text(
              'Data pengajuan belum lengkap. Silakan ulangi dari awal.',
              style: TextStyle(color: theme.colorScheme.error),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SummaryRow(label: 'Jenis Cuti', value: draft.leaveTypeName ?? '-'),
                    const Divider(height: 20),
                    _SummaryRow(
                      label: 'Tanggal',
                      value:
                          '${formatDateLong(draft.startDate)} – ${formatDateLong(draft.endDate)}',
                    ),
                    const Divider(height: 20),
                    _SummaryRow(label: 'Total Hari Kerja', value: '$days hari'),
                    const Divider(height: 20),
                    _SummaryRow(
                      label: 'Alasan',
                      value: draft.reason.isEmpty ? '-' : draft.reason,
                    ),
                    const Divider(height: 20),
                    _SummaryRow(label: 'Dokumen', value: draft.documentName ?? '-'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Kirim Pengajuan',
              loading: _loading,
              onPressed: complete ? _submit : null,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : () => context.pop(),
              child: const Text('Kembali'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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
