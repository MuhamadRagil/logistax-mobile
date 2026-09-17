import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/loan_model.dart';
import '../data/loans_repository.dart';

/// Repository pinjaman (single instance per lifecycle app).
final loansRepositoryProvider = Provider<LoansRepository>((ref) => LoansRepository());

/// Daftar pinjaman saya (backend otomatis memfilter milik sendiri).
final myLoansProvider = FutureProvider.autoDispose<List<EmployeeLoan>>((ref) {
  return ref.watch(loansRepositoryProvider).myLoans();
});
