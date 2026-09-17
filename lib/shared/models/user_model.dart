import 'dart:convert';

import 'model_utils.dart';

/// User login (dari /auth/login dan /users/me).
class AppUser {
  final String id;
  final String email;
  final String role; // super_admin | hrd | spv | employee
  final EmployeeSummary? employee;

  const AppUser({required this.id, required this.email, required this.role, this.employee});

  bool get isSpv => role == 'spv';
  bool get isEmployeeOnly => role == 'employee';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        employee: json['employee'] is Map<String, dynamic>
            ? EmployeeSummary.fromJson(json['employee'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'employee': employee?.toJson(),
      };

  String encode() => jsonEncode(toJson());

  static AppUser? decode(String? raw) {
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class EmployeeSummary {
  final String id;
  final String nik;
  final String fullName;
  final String? photoUrl;
  final String? departmentName;
  final String? positionName;

  const EmployeeSummary({
    required this.id,
    required this.nik,
    required this.fullName,
    this.photoUrl,
    this.departmentName,
    this.positionName,
  });

  factory EmployeeSummary.fromJson(Map<String, dynamic> json) => EmployeeSummary(
        id: json['id'] as String,
        nik: toStr(json['nik']) ?? '',
        fullName: toStr(json['fullName']) ?? '',
        photoUrl: toStr(json['photoUrl']),
        departmentName: json['department'] is Map ? toStr(json['department']['name']) : null,
        positionName: json['position'] is Map ? toStr(json['position']['name']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nik': nik,
        'fullName': fullName,
        'photoUrl': photoUrl,
        'department': departmentName == null ? null : {'name': departmentName},
        'position': positionName == null ? null : {'name': positionName},
      };
}
