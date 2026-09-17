import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/payslip_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/payroll_repository.dart';

/// Repository slip gaji (single instance per lifecycle app).
final payrollRepositoryProvider = Provider<PayrollRepository>((ref) => PayrollRepository());

/// Daftar slip gaji saya. Kosong bila akun tidak terhubung ke data karyawan.
final mySlipsProvider = FutureProvider.autoDispose<List<Payslip>>((ref) {
  final employeeId = ref.watch(authControllerProvider).employeeId;
  if (employeeId == null) return Future.value(const <Payslip>[]);
  return ref.watch(payrollRepositoryProvider).mySlips(employeeId);
});

/// Detail satu slip gaji berdasarkan id.
final slipDetailProvider = FutureProvider.autoDispose.family<Payslip, String>((ref, id) {
  return ref.watch(payrollRepositoryProvider).slip(id);
});
