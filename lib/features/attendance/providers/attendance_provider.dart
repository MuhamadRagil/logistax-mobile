import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/office_location_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/attendance_repository.dart';

/// Repository absensi (single instance per lifecycle app).
final attendanceRepositoryProvider =
    Provider<AttendanceRepository>((ref) => AttendanceRepository());

/// Status absensi saya hari ini (null = belum absen).
final myTodayProvider = FutureProvider.autoDispose<AttendanceRecord?>((ref) {
  return ref.watch(attendanceRepositoryProvider).myToday();
});

/// Pengaturan absensi (titik kantor + radius GPS) dari server.
/// Dipakai halaman tombol absensi untuk menghitung jarak ke kantor.
final attendanceSettingsProvider = FutureProvider.autoDispose<AttendanceSettings>((ref) {
  return ref.watch(attendanceRepositoryProvider).settings();
});

/// Lokasi absensi yang di-assign ke saya. List kosong = pakai titik kantor
/// global dari settings. Error (mis. 403 karena role) juga jatuh ke list
/// kosong; server tetap jadi validator akhir saat check-in.
final myLocationsProvider = FutureProvider.autoDispose<List<OfficeLocation>>((ref) async {
  final employeeId = ref.watch(authControllerProvider).employeeId;
  if (employeeId == null) return const [];
  try {
    return await ref.watch(attendanceRepositoryProvider).employeeLocations(employeeId);
  } catch (_) {
    return const [];
  }
});

/// Rekap absensi bulanan saya untuk (year, month) tertentu.
final myMonthlyProvider = FutureProvider.autoDispose
    .family<AttendanceMonthlyEmployee?, ({int year, int month})>((ref, params) {
  return ref.watch(attendanceRepositoryProvider).myMonthly(params.year, params.month);
});
