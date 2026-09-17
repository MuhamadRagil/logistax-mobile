import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_util.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';

/// Jadwal cicilan pinjaman. Backend tidak menyediakan endpoint riwayat cicilan,
/// jadi jadwal dihitung di sisi klien dari data pinjaman.
class LoanHistoryPage extends ConsumerWidget {
  final EmployeeLoan? loan;

  const LoanHistoryPage({super.key, this.loan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = loan;

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Cicilan')),
        body: const EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Pilih pinjaman dari halaman Pinjaman',
          description: 'Buka halaman Pinjaman lalu tekan "Lihat Riwayat Cicilan".',
        ),
      );
    }

    final rows = _schedule(data);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Cicilan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 10),
                    child: Text(
                      'Jadwal Cicilan (${rows.length}x ${formatRupiah(data.monthlyInstallment)})',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const _HeaderRow(),
                  const Divider(height: 12),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Jadwal cicilan tidak tersedia.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ...rows.map((r) => _InstallmentRow(row: r)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Jadwal dihitung dari sisa pinjaman; pemotongan aktual terjadi saat payroll difinalisasi.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bangun jadwal cicilan: cicilan terakhir menyesuaikan sisa saldo.
  List<_ScheduleRow> _schedule(EmployeeLoan loan) {
    final rows = <_ScheduleRow>[];
    var balance = loan.totalAmount;

    for (var i = 0; i < loan.totalInstallments; i++) {
      if (balance <= 0) break;
      final amount = loan.monthlyInstallment < balance ? loan.monthlyInstallment : balance;
      balance -= amount;
      final period = DateTime(loan.startYear, loan.startMonth + i);
      rows.add(_ScheduleRow(
        index: i + 1,
        period: period,
        amount: amount,
        remaining: balance,
        paid: i < loan.paidInstallments,
      ));
    }
    return rows;
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Expanded(flex: 2, child: Text('#', style: style)),
        Expanded(flex: 7, child: Text('Periode', style: style)),
        Expanded(flex: 6, child: Text('Jumlah', style: style, textAlign: TextAlign.right)),
        Expanded(flex: 6, child: Text('Sisa', style: style, textAlign: TextAlign.right)),
        Expanded(flex: 6, child: Text('Status', style: style, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final _ScheduleRow row;

  const _InstallmentRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cell = theme.textTheme.bodySmall?.copyWith(fontSize: 11);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text('${row.index}', style: cell?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 7,
            child: Text(
              monthLabel(row.period.month, row.period.year),
              style: cell,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              formatRupiah(row.amount),
              textAlign: TextAlign.right,
              style: cell?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              formatRupiah(row.remaining),
              textAlign: TextAlign.right,
              style: cell?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerRight,
              child: StatusBadge(
                label: row.paid ? 'Terpotong' : 'Menunggu',
                color: row.paid ? AppColors.success : AppColors.holiday,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris jadwal cicilan hasil perhitungan klien.
class _ScheduleRow {
  final int index;
  final DateTime period;
  final num amount;
  final num remaining;
  final bool paid;

  const _ScheduleRow({
    required this.index,
    required this.period,
    required this.amount,
    required this.remaining,
    required this.paid,
  });
}
