import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/kpi_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/kpi_repository.dart';

/// Repository KPI (satu instance selama app hidup).
final kpiRepositoryProvider = Provider<KpiRepository>((ref) => KpiRepository());

/// Periode yang sedang dilihat — dipakai bersama oleh halaman KPI Saya,
/// Tren, dan Leaderboard agar filter bulan tetap konsisten.
final kpiPeriodProvider = StateProvider<({int year, int month})>((ref) {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
});

/// Detail KPI saya pada periode terpilih.
/// Bernilai null bila akun tidak terhubung dengan data karyawan.
final myKpiProvider = FutureProvider.autoDispose<KpiEmployeeDetail?>((ref) async {
  final period = ref.watch(kpiPeriodProvider);
  final employeeId = ref.watch(authControllerProvider).employeeId;
  if (employeeId == null) return null;
  return ref.watch(kpiRepositoryProvider).myKpi(employeeId, period.year, period.month);
});

/// Leaderboard perusahaan pada periode terpilih.
/// Bisa gagal (role employee sebelum finalisasi) — ditangani di halaman.
final kpiLeaderboardProvider = FutureProvider.autoDispose<KpiMonthly>((ref) {
  final period = ref.watch(kpiPeriodProvider);
  return ref.watch(kpiRepositoryProvider).monthly(period.year, period.month);
});
