import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/leave_model.dart';
import '../data/leave_repository.dart';

/// Repository cuti.
final leaveRepositoryProvider = Provider<LeaveRepository>((ref) => LeaveRepository());

/// Daftar jenis cuti.
final leaveTypesProvider = FutureProvider.autoDispose<List<LeaveType>>((ref) {
  return ref.watch(leaveRepositoryProvider).types();
});

/// Saldo cuti saya per tahun.
final myBalancesProvider =
    FutureProvider.autoDispose.family<List<LeaveBalance>, int>((ref, year) {
  return ref.watch(leaveRepositoryProvider).myBalances(year);
});

/// Riwayat pengajuan cuti saya.
final myLeaveRequestsProvider = FutureProvider.autoDispose<List<LeaveRequest>>((ref) {
  return ref.watch(leaveRepositoryProvider).myRequests();
});

/// State draft form pengajuan cuti — bertahan lintas 3 halaman form
/// (BUKAN autoDispose).
class LeaveDraft {
  final String? leaveTypeId;
  final String? leaveTypeName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String reason;
  final String? documentName;

  const LeaveDraft({
    this.leaveTypeId,
    this.leaveTypeName,
    this.startDate,
    this.endDate,
    this.reason = '',
    this.documentName,
  });

  bool get hasDates => startDate != null && endDate != null;

  LeaveDraft copyWith({
    String? leaveTypeId,
    String? leaveTypeName,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? documentName,
    bool clearDocument = false,
  }) {
    return LeaveDraft(
      leaveTypeId: leaveTypeId ?? this.leaveTypeId,
      leaveTypeName: leaveTypeName ?? this.leaveTypeName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      documentName: clearDocument ? null : (documentName ?? this.documentName),
    );
  }
}

/// Draft form aktif. Tidak autoDispose agar bertahan saat berpindah halaman form.
final leaveDraftProvider = StateProvider<LeaveDraft>((ref) => const LeaveDraft());

/// Reset draft ke kondisi kosong (dipanggil sebelum mulai/selesai pengajuan).
void resetLeaveDraft(WidgetRef ref) {
  ref.read(leaveDraftProvider.notifier).state = const LeaveDraft();
}
