import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'empty_state.dart';
import 'error_state.dart';

/// KPI ditolak backend sebelum finalisasi (403/404) → "belum tersedia".
/// Error lain (jaringan, 500) tetap tampil sebagai error dengan tombol coba lagi,
/// supaya masalah koneksi tidak tersamar jadi "belum dinilai".
class KpiErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String unavailableTitle;
  final String unavailableDescription;

  const KpiErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.unavailableTitle = 'Nilai KPI belum tersedia bulan ini',
    this.unavailableDescription = 'Nilai dipublikasikan setelah HRD melakukan finalisasi.',
  });

  @override
  Widget build(BuildContext context) {
    final code = ApiException.fromDio(error).statusCode;
    final notPublishedYet = code == 403 || code == 404;

    if (notPublishedYet) {
      return EmptyState(
        icon: Icons.insights_rounded,
        title: unavailableTitle,
        description: unavailableDescription,
      );
    }
    return ErrorState(error: error, onRetry: onRetry);
  }
}
