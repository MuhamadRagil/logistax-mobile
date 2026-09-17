import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_util.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../providers/loans_provider.dart';

/// Status pinjaman saya: pinjaman aktif + riwayat pinjaman lama.
class LoanStatusPage extends ConsumerWidget {
  const LoanStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myLoansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pinjaman')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myLoansProvider),
        child: async.when(
          loading: () => const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(count: 2, height: 200),
          ),
          error: (e, _) => _fill(
            ErrorState(error: e, onRetry: () => ref.invalidate(myLoansProvider)),
          ),
          data: (loans) {
            final active = loans.where((l) => l.status == 'active').toList();
            final past = loans.where((l) => l.status != 'active').toList();

            if (active.isEmpty && past.isEmpty) {
              return _fill(const _NoActiveLoan());
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: _NoActiveLoan(),
                  )
                else
                  ...active.map((l) => _ActiveLoanCard(loan: l)),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Riwayat Pinjaman',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...past.map((l) => _PastLoanTile(loan: l)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Bungkus konten non-scrollable agar pull-to-refresh tetap berfungsi.
  Widget _fill(Widget child) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      );
}

class _NoActiveLoan extends StatelessWidget {
  const _NoActiveLoan();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Tidak ada pinjaman aktif',
      description:
          'Saat ini Anda tidak memiliki pinjaman berjalan. Pengajuan pinjaman dilakukan melalui HRD.',
    );
  }
}

class _ActiveLoanCard extends StatelessWidget {
  final EmployeeLoan loan;

  const _ActiveLoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = loan.progressPct.clamp(0, 100).toDouble();
    final now = DateTime.now();
    final target = DateTime(now.year, now.month + loan.remainingMonths);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Pinjaman',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatRupiah(loan.totalAmount),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: AppStrings.loanStatusLabel[loan.status] ?? loan.status,
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _row(context, 'Sisa Pokok', formatRupiah(loan.remainingAmount),
                valueColor: AppColors.teal, bold: true),
            _row(context, 'Cicilan/Bulan', formatRupiah(loan.monthlyInstallment)),
            _row(context, 'Keperluan', loan.purpose ?? '-'),
            _row(context, 'Mulai', monthLabel(loan.startMonth, loan.startYear)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 8,
                color: AppColors.teal,
                backgroundColor: AppColors.teal.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Terbayar ${formatRupiah(loan.paidAmount)} dari ${formatRupiah(loan.totalAmount)} '
              '(${pct.toStringAsFixed(0)}%)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_available_rounded,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Estimasi lunas: ${loan.remainingMonths} bulan lagi '
                    '(${monthLabel(target.month, target.year)})',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/pinjaman/riwayat', extra: loan),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Lihat Riwayat Cicilan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PastLoanTile extends StatelessWidget {
  final EmployeeLoan loan;

  const _PastLoanTile({required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = loan.status == 'completed' ? AppColors.success : AppColors.holiday;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatRupiah(loan.totalAmount),
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${loan.purpose ?? '-'} • Mulai ${monthLabel(loan.startMonth, loan.startYear)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(
              label: AppStrings.loanStatusLabel[loan.status] ?? loan.status,
              color: color,
              fontSize: 11,
            ),
          ],
        ),
      ),
    );
  }
}
