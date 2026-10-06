import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../models/intern_models.dart';
import '../../providers/intern_providers.dart';

/// Nilai evaluasi magang. "Evaluasi belum tersedia" dari backend = state
/// kosong, bukan error.
class InternEvaluationPage extends ConsumerWidget {
  const InternEvaluationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(internEvaluationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nilai Saya')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(internEvaluationProvider);
          await ref.read(internEvaluationProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 80),
              ErrorState(error: e, onRetry: () => ref.invalidate(internEvaluationProvider)),
            ],
          ),
          data: (eval) => eval == null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.hourglass_empty_rounded,
                      title: 'Evaluasi belum tersedia',
                      description:
                          'Nilai akan muncul di sini setelah mentor/admin menyelesaikan evaluasi magang Anda.',
                    ),
                  ],
                )
              : _EvaluationView(eval: eval),
        ),
      ),
    );
  }
}

class _EvaluationView extends StatelessWidget {
  const _EvaluationView({required this.eval});

  final InternEvaluation eval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = [
      ('Kedisiplinan', eval.discipline),
      ('Kinerja', eval.performance),
      ('Sikap', eval.attitude),
      ('Komunikasi', eval.communication),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.navy, AppColors.teal]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nilai Total', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      _fmt(eval.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 72,
                width: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Text(
                  eval.grade ?? '-',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final (label, score) in categories) ...[
                  Row(
                    children: [
                      Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                      Text(
                        _fmt(score),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      color: AppColors.teal,
                      backgroundColor: AppColors.tealLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        if (eval.comments != null && eval.comments!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.format_quote_rounded, color: AppColors.teal),
              title: const Text('Catatan Evaluator'),
              subtitle: Text(eval.comments!),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push('/intern/sertifikat'),
          icon: const Icon(Icons.workspace_premium_rounded),
          label: const Text('Lihat Sertifikat'),
        ),
      ],
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
