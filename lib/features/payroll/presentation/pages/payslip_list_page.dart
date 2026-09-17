import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_util.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/payslip_model.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../providers/payroll_provider.dart';

/// Daftar slip gaji saya, terbaru di atas.
class PayslipListPage extends ConsumerWidget {
  const PayslipListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySlipsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Slip Gaji')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mySlipsProvider),
        child: async.when(
          loading: () => const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(count: 5),
          ),
          error: (e, _) => _fill(
            ErrorState(error: e, onRetry: () => ref.invalidate(mySlipsProvider)),
          ),
          data: (slips) {
            if (slips.isEmpty) {
              return _fill(
                const EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'Belum ada slip gaji',
                  description: 'Slip gaji akan muncul setelah payroll bulan berjalan difinalisasi.',
                ),
              );
            }

            final sorted = [...slips]..sort((a, b) {
                final byYear = b.periodYear.compareTo(a.periodYear);
                return byYear != 0 ? byYear : b.periodMonth.compareTo(a.periodMonth);
              });

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: sorted.length,
              itemBuilder: (context, i) => _SlipCard(slip: sorted[i]),
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

class _SlipCard extends StatelessWidget {
  final Payslip slip;

  const _SlipCard({required this.slip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/slip/${slip.id}', extra: slip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.tealLight,
                child: Icon(Icons.receipt_long_rounded, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel(slip.periodMonth, slip.periodYear),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Take Home Pay',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatRupiah(slip.takeHomePay),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
