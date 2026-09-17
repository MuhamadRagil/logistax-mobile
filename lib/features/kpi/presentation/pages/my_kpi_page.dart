import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/models/kpi_model.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/kpi_error_view.dart';
import '../../../../shared/widgets/kpi_tier_badge.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/kpi_provider.dart';

/// Bottom sheet pemilih bulan & tahun — dipakai bersama halaman KPI Saya
/// dan Leaderboard karena keduanya membaca [kpiPeriodProvider] yang sama.
Future<void> showKpiPeriodPicker(BuildContext context, WidgetRef ref) {
  final now = DateTime.now();
  final current = ref.read(kpiPeriodProvider);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      var year = current.year;
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final theme = Theme.of(sheetContext);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pilih Periode', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => setSheetState(() => year--),
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Tahun sebelumnya',
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '$year',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: year >= now.year
                            ? null
                            : () => setSheetState(() => year++),
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Tahun berikutnya',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    childAspectRatio: 2.3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: List.generate(12, (i) {
                      final month = i + 1;
                      final isSelected =
                          year == current.year && month == current.month;
                      final isFuture =
                          year > now.year || (year == now.year && month > now.month);
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: isFuture
                            ? null
                            : () {
                                ref.read(kpiPeriodProvider.notifier).state =
                                    (year: year, month: month);
                                Navigator.of(sheetContext).pop();
                              },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.teal
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            AppStrings.bulan[i].substring(0, 3),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.white
                                  : isFuture
                                      ? theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4)
                                      : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Halaman utama KPI: skor bulan berjalan + rincian per kategori.
class MyKpiPage extends ConsumerWidget {
  const MyKpiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(kpiPeriodProvider);
    final employeeId = ref.watch(authControllerProvider).employeeId;
    final asyncKpi = ref.watch(myKpiProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI Saya'),
        actions: [
          IconButton(
            onPressed: () => showKpiPeriodPicker(context, ref),
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Pilih periode',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myKpiProvider),
        child: asyncKpi.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(count: 3, height: 120),
          ),
          // 403/404 = belum difinalisasi HRD; error lain (jaringan/500)
          // tetap ditampilkan apa adanya agar tidak menyamarkan masalah koneksi.
          error: (e, _) => _scrollable(
            child: KpiErrorView(
              error: e,
              onRetry: () => ref.invalidate(myKpiProvider),
            ),
          ),
          data: (detail) {
            if (employeeId == null) {
              return _scrollable(
                child: const EmptyState(
                  icon: Icons.person_off_rounded,
                  title: 'Akun tidak terhubung dengan data karyawan',
                  description: 'Hubungi HRD untuk menautkan akun Anda.',
                ),
              );
            }

            final summary = detail?.summary;
            if (summary == null || detail!.breakdown.isEmpty) {
              return _scrollable(child: const _KpiUnavailable());
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Center(
                  child: Text(
                    '${AppStrings.bulan[period.month - 1]} ${period.year}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                _ScoreSection(summary: summary),
                if (summary.isEmployeeOfMonth) ...[
                  const SizedBox(height: 20),
                  const _EmployeeOfMonthBanner(),
                ],
                const SizedBox(height: 20),
                _BreakdownCard(items: detail.breakdown),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => context.push('/kpi/riwayat'),
                  icon: const Icon(Icons.show_chart_rounded),
                  label: const Text('Lihat Tren'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/kpi/leaderboard'),
                  icon: const Icon(Icons.leaderboard_rounded),
                  label: const Text('Lihat Leaderboard'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Pembungkus agar pull-to-refresh tetap bekerja pada tampilan kosong.
  Widget _scrollable({required Widget child}) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      );
}

class _KpiUnavailable extends StatelessWidget {
  const _KpiUnavailable();

  @override
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.insights_rounded,
        title: 'Nilai KPI belum tersedia bulan ini',
        description: 'Nilai dipublikasikan setelah HRD melakukan finalisasi.',
      );
}

class _ScoreSection extends StatelessWidget {
  final KpiSummary summary;

  const _ScoreSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColor = AppColors.kpiTier(summary.tier);

    return Column(
      children: [
        Text(
          summary.totalScore.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: tierColor,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        KpiTierBadge(tier: summary.tier, fontSize: 14),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (summary.totalScore / 100).clamp(0.0, 1.0),
            minHeight: 10,
            color: tierColor,
            backgroundColor: tierColor.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Peringkat #${summary.rankInCompany} di perusahaan',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EmployeeOfMonthBanner extends StatelessWidget {
  const _EmployeeOfMonthBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navy, AppColors.teal],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: const Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: 28)),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Employee of the Month!',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final List<KpiBreakdownItem> items;

  const _BreakdownCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rincian Penilaian', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 5, child: Text('Kategori', style: headerStyle)),
                Expanded(
                  flex: 2,
                  child: Text('Bobot',
                      textAlign: TextAlign.end, style: headerStyle),
                ),
                Expanded(
                  flex: 2,
                  child:
                      Text('Skor', textAlign: TextAlign.end, style: headerStyle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Nilai',
                      textAlign: TextAlign.end, style: headerStyle),
                ),
              ],
            ),
            const Divider(height: 18),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 18),
              _BreakdownRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final KpiBreakdownItem item;

  const _BreakdownRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(item.categoryName, style: valueStyle),
                  ),
                  if (item.isAutoCalculated) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'otomatis',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  item.notes!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${item.weightPct.toStringAsFixed(0)}%',
            textAlign: TextAlign.end,
            style: valueStyle,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            item.rawScore.toStringAsFixed(0),
            textAlign: TextAlign.end,
            style: valueStyle,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            item.weightedScore.toStringAsFixed(1),
            textAlign: TextAlign.end,
            style: valueStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
