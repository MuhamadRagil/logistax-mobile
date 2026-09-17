import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/employee_model.dart';
import '../data/profile_repository.dart';

/// Repository profil (single instance per lifecycle app).
final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository());

/// Profil karyawan saya (null bila akun tidak terhubung dengan data karyawan).
final myProfileProvider = FutureProvider.autoDispose<EmployeeProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).myProfile();
});
