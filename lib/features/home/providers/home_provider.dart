import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/kpi_model.dart';
import '../../../shared/models/leave_model.dart';
import '../../../shared/models/notification_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/home_repository.dart';

/// Repository Beranda (dipakai juga oleh aksi check-out di halaman).
final homeRepositoryProvider = Provider<HomeRepository>((ref) => HomeRepository());

/// Absensi saya hari ini (bisa null = belum absen).
final homeTodayProvider = FutureProvider.autoDispose<AttendanceRecord?>((ref) {
  return ref.watch(homeRepositoryProvider).myToday();
});

/// Saldo cuti saya tahun berjalan.
final homeBalancesProvider = FutureProvider.autoDispose<List<LeaveBalance>>((ref) {
  return ref.watch(homeRepositoryProvider).myBalances(DateTime.now().year);
});

/// KPI saya bulan ini — null bila employeeId tidak ada ATAU API menolak
/// (kartu menampilkan "Belum tersedia").
final homeKpiProvider = FutureProvider.autoDispose<KpiEmployeeDetail?>((ref) async {
  final employeeId = ref.watch(authControllerProvider).employeeId;
  if (employeeId == null) return null;
  final now = DateTime.now();
  try {
    return await ref.watch(homeRepositoryProvider).myKpi(employeeId, now.year, now.month);
  } catch (_) {
    return null;
  }
});

/// Total jam lembur bulan ini — 0 bila gagal.
final homeOvertimeProvider = FutureProvider.autoDispose<double>((ref) async {
  final now = DateTime.now();
  try {
    return await ref.watch(homeRepositoryProvider).overtimeHours(now.year, now.month);
  } catch (_) {
    return 0;
  }
});

/// 3 notifikasi terbaru.
final homeNotificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) {
  return ref.watch(homeRepositoryProvider).latestNotifications();
});

/// Ringkasan absensi tim hari ini — hanya untuk yang boleh melihat tim.
final homeTeamTodayProvider =
    FutureProvider.autoDispose<({int total, int checkedIn})?>((ref) {
  final canSeeTeam = ref.watch(authControllerProvider).canSeeTeam;
  if (!canSeeTeam) return Future.value(null);
  return ref.watch(homeRepositoryProvider).teamToday();
});
