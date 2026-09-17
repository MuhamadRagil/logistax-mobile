import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/employee_model.dart';
import '../../../shared/models/leave_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/spv_repository.dart';

/// Repository tim/supervisor.
final spvRepositoryProvider = Provider<SpvRepository>((ref) => SpvRepository());

/// Papan absensi tim hari ini.
///
/// Backend `/attendance/today` mengembalikan SEMUA karyawan, jadi untuk role
/// `spv` hasilnya disaring client-side ke bawahan langsung
/// (`supervisorId == employeeId saya`). Role hrd/super_admin melihat penuh.
final teamTodayProvider = FutureProvider.autoDispose<List<TodayBoardItem>>((ref) async {
  final repo = ref.watch(spvRepositoryProvider);
  final auth = ref.watch(authControllerProvider);
  final myEmployeeId = auth.employeeId;
  final role = auth.user?.role;

  // Future.wait meneruskan error pertama apa adanya (ApiException) sehingga
  // pesan 403 dari backend tetap utuh di ErrorState.
  final results = await Future.wait<Object>([repo.todayBoard(), repo.teamMembers()]);
  final board = results[0] as List<TodayBoardItem>;
  final members = results[1] as List<TeamMember>;

  // hrd/super_admin: papan penuh tanpa filter.
  if (role != 'spv' || myEmployeeId == null) return board;

  final subordinateIds = members
      .where((m) => m.supervisorId == myEmployeeId)
      .map((m) => m.id)
      .toSet();

  return board.where((item) => subordinateIds.contains(item.employeeId)).toList();
});

/// Pengajuan cuti yang menunggu persetujuan (backend sudah membatasi ke bawahan).
final pendingLeavesProvider = FutureProvider.autoDispose<List<LeaveRequest>>((ref) {
  return ref.watch(spvRepositoryProvider).pendingLeaves();
});
