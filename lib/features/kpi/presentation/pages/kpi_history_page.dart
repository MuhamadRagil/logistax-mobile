import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/models/kpi_model.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/kpi_error_view.dart';
import '../../../../shared/widgets/kpi_tier_badge.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../providers/kpi_provider.dart';

/// Tren skor KPI beberapa periode terakhir.
class KpiHistoryPage extends ConsumerWidget {
  const KpiHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncKpi = ref.watch(myKpiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tren KPI')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myKpiProvider),
        child: asyncKpi.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(count: 2, height: 160),
          ),
          error: (e, _) => _scrollable(
            child: KpiErrorView(
              error: e,
              onRetry: () => ref.invalidate(myKpiProvider),
              unavailableTitle: 'Tren KPI belum tersedia',
              unavailableDescription: 'Nilai dipublikasikan setelah HRD melakukan finalisasi.',
            ),
          ),
          data: (detail) {
            final points = [...?detail?.trend]
              ..sort((a, b) => a.year == b.year
                  ? a.month.compareTo(b.month)
                  : a.year.compareTo(b.year));

            if (points.length < 2) {
              return _scrollable(child: const _NotEnoughData());
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
                    child: AspectRatio(
                      aspectRatio: 1.4,
                      child: _TrendChart(points: points),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Riwayat Nilai',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    child: Column(
                      children: [
                        for (var i = points.length - 1; i >= 0; i--) ...[
                          if (i < points.length - 1) const Divider(height: 1),
                          _TrendRow(point: points[i]),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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

class _NotEnoughData extends StatelessWidget {
  const _NotEnoughData();

  @override
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.show_chart_rounded,
        title: 'Belum cukup data tren',
        description: 'Tren muncul setelah Anda memiliki nilai KPI '
            'minimal dua periode.',
      );
}

class _TrendChart extends StatelessWidget {
  final List<KpiTrendPoint> points;

  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 34,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: labelStyle,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (value, _) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppStrings.bulan[points[index].month - 1].substring(0, 3),
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipColor: (_) => AppColors.navy,
            getTooltipItems: (spots) => spots.map((spot) {
              final point = points[spot.x.round().clamp(0, points.length - 1)];
              final tierLabel =
                  AppStrings.kpiTierLabel[point.tier] ?? point.tier;
              return LineTooltipItem(
                '${AppStrings.bulan[point.month - 1]} ${point.year}\n'
                'Skor ${point.totalScore.toStringAsFixed(1)} • $tierLabel',
                const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].totalScore),
            ],
            isCurved: true,
            color: AppColors.teal,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, _, index) => FlDotCirclePainter(
                radius: 5,
                color: AppColors.kpiTier(
                  points[index.clamp(0, points.length - 1)].tier,
                ),
                strokeColor: AppColors.white,
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.teal.withValues(alpha: 0.15),
                  AppColors.teal.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final KpiTrendPoint point;

  const _TrendRow({required this.point});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${AppStrings.bulan[point.month - 1]} ${point.year}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            point.totalScore.toStringAsFixed(1),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.kpiTier(point.tier),
            ),
          ),
          const SizedBox(width: 12),
          KpiTierBadge(tier: point.tier),
        ],
      ),
    );
  }
}
