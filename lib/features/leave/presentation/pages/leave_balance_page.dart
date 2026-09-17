import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/leave_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/logistax_app_bar.dart';
import '../../providers/leave_provider.dart';

/// Halaman saldo cuti — daftar sisa cuti per jenis + tombol aksi.
class LeaveBalancePage extends ConsumerWidget {
  const LeaveBalancePage({super.key});

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('tahunan')) return Icons.beach_access;
    if (n.contains('sakit')) return Icons.healing;
    return Icons.event;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = DateTime.now().year;
    final balances = ref.watch(myBalancesProvider(year));

    return Scaffold(
      appBar: const LogistaxAppBar(title: 'Cuti & Izin'),
      body: balances.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingShimmer(count: 4, height: 96),
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(myBalancesProvider(year)),
        ),
        data: (rawList) {
          // Sakit & Izin dilaporkan lewat tab Absensi, bukan lewat saldo cuti.
          final list = rawList.where((b) {
            final n = b.leaveTypeName.toLowerCase();
            return !n.contains('sakit') && !n.contains('izin');
          }).toList();
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.beach_access_outlined,
              title: 'Saldo cuti belum diatur',
              description: 'Hubungi HRD untuk pengaturan saldo cuti Anda.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myBalancesProvider(year)),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              itemBuilder: (context, i) => _BalanceCard(
                balance: list[i],
                icon: _iconFor(list[i].leaveTypeName),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Ajukan Cuti',
                  icon: Icons.add,
                  onPressed: () {
                    resetLeaveDraft(ref);
                    context.push('/cuti/ajukan');
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/cuti/riwayat'),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Lihat Riwayat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final LeaveBalance balance;
  final IconData icon;

  const _BalanceCard({required this.balance, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quota = balance.quota;
    final used = balance.usedDays;
    final progress = quota > 0 ? (used / quota).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.tealLight,
                  child: Icon(icon, color: AppColors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    balance.leaveTypeName.isEmpty ? 'Cuti' : balance.leaveTypeName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 8,
                color: AppColors.teal,
                backgroundColor: AppColors.tealLight,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${balance.remaining} hari tersisa dari $quota hari',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'terpakai $used',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
