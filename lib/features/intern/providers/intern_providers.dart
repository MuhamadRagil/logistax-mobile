import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/intern_repository.dart';
import '../models/intern_models.dart';

final internRepositoryProvider = Provider<InternRepository>((ref) => InternRepository());

/// Record absensi hari ini (tanggal versi server/UTC), null bila belum ada.
final internTodayProvider = FutureProvider.autoDispose<InternAttendance?>((ref) async {
  final today = internServerToday();
  final history = await ref
      .watch(internRepositoryProvider)
      .myHistory(year: today.year, month: today.month);
  final key = dateKey(today);
  for (final a in history) {
    if (a.date == key) return a;
  }
  return null;
});

/// Riwayat absensi per bulan (terbaru di atas).
final internHistoryProvider = FutureProvider.autoDispose
    .family<List<InternAttendance>, ({int year, int month})>((ref, period) async {
  final list = await ref
      .watch(internRepositoryProvider)
      .myHistory(year: period.year, month: period.month);
  return list.reversed.toList();
});

final internEvaluationProvider = FutureProvider.autoDispose<InternEvaluation?>((ref) {
  return ref.watch(internRepositoryProvider).myEvaluation();
});

final internCertificateProvider = FutureProvider.autoDispose<InternCertificate?>((ref) {
  return ref.watch(internRepositoryProvider).myCertificate();
});
