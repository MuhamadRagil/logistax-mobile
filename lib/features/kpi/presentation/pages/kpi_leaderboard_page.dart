import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/models/kpi_model.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/kpi_error_view.dart';
import '../../../../shared/widgets/kpi_tier_badge.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/kpi_provider.dart';
import 'my_kpi_page.dart' show showKpiPeriodPicker;

const _gold = Color(0xFFFFC107);
const _silver = Color(0xFFB0BEC5);
const _bronze = Color(0xFFCD7F32);

/// Peringkat KPI seluruh karyawan pada periode terpilih.
class KpiLeaderboardPage extends ConsumerWidget {
  const KpiLeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(kpiPeriodProvider);
    final myEmployeeId = ref.watch(authControllerProvider).employeeId;
    final asyncBoard = ref.watch(kpiLeaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            onPressed: () => showKpiPeriodPicker(context, ref),
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Pilih periode',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(kpiLeaderboardProvider),
        child: asyncBoard.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(count: 4, height: 76),
          ),
          // 403/404 = periode belum difinalisasi; error lain tampil apa adanya.
          error: (e, _) => _scrollable(
            child: KpiErrorView(
              error: e,
              onRetry: () => ref.invalidate(kpiLeaderboardProvider),
              unavailableTitle: 'Leaderboard belum tersedia',
              unavailableDescription: 'Data KPI bulan ini belum difinalisasi.',
            ),
          ),
          data: (board) {
            final entries = board.leaderboard;
            if (entries.isEmpty) {
              return _scrollable(child: const _BoardUnavailable());
            }

            final hasPodium = entries.length >= 3;
            final rest = hasPodium ? entries.sublist(3) : entries;

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
                const SizedBox(height: 20),
                if (hasPodium) ...[
                  _Podium(top: entries.take(3).toList()),
                  const SizedBox(height: 24),
                ],
                for (var i = 0; i < rest.length; i++)
                  _LeaderboardTile(
                    entry: rest[i],
                    rank: hasPodium ? i + 4 : i + 1,
                    isMe: myEmployeeId != null &&
                        rest[i].employeeId == myEmployeeId,
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

class _BoardUnavailable extends StatelessWidget {
  const _BoardUnavailable();

  @override
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.leaderboard_rounded,
        title: 'Leaderboard belum tersedia',
        description: 'Data KPI bulan ini belum difinalisasi.',
      );
}

/// Podium tiga besar: juara 2 (kiri), juara 1 (tengah), juara 3 (kanan).
class _Podium extends StatelessWidget {
  final List<KpiSummary> top;

  const _Podium({required this.top});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumSpot(
            entry: top[1],
            rank: 2,
            color: _silver,
            avatarSize: 56,
            pedestalHeight: 70,
          ),
        ),
        Expanded(
          child: _PodiumSpot(
            entry: top[0],
            rank: 1,
            color: _gold,
            avatarSize: 72,
            pedestalHeight: 95,
            showCrown: true,
          ),
        ),
        Expanded(
          child: _PodiumSpot(
            entry: top[2],
            rank: 3,
            color: _bronze,
            avatarSize: 52,
            pedestalHeight: 55,
          ),
        ),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final KpiSummary entry;
  final int rank;
  final Color color;
  final double avatarSize;
  final double pedestalHeight;
  final bool showCrown;

  const _PodiumSpot({
    required this.entry,
    required this.rank,
    required this.color,
    required this.avatarSize,
    required this.pedestalHeight,
    this.showCrown = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCrown)
          const Text('👑', style: TextStyle(fontSize: 22))
        else
          const SizedBox(height: 22),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
          child: _EmployeeAvatar(entry: entry, size: avatarSize),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            entry.employeeName ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          entry.totalScore.toStringAsFixed(1),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.kpiTier(entry.tier),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: pedestalHeight,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Text(
            '$rank',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final KpiSummary entry;
  final int rank;
  final bool isMe;

  const _LeaderboardTile({
    required this.entry,
    required this.rank,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.teal.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: AppColors.teal.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Text(
              '$rank',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          _EmployeeAvatar(entry: entry, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.employeeName ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Anda',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.departmentName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.departmentName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.totalScore.toStringAsFixed(1),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.kpiTier(entry.tier),
                ),
              ),
              const SizedBox(height: 3),
              KpiTierBadge(tier: entry.tier, fontSize: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Foto karyawan dengan fallback inisial nama.
class _EmployeeAvatar extends StatelessWidget {
  final KpiSummary entry;
  final double size;

  const _EmployeeAvatar({required this.entry, required this.size});

  @override
  Widget build(BuildContext context) {
    final photoUrl = entry.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.navy.withValues(alpha: 0.12),
      backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl) : null,
      child: hasPhoto
          ? null
          : Text(
              _initials(entry.employeeName),
              style: TextStyle(
                fontSize: size / 2.8,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
    );
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }
}
