import 'model_utils.dart';

/// Profil karyawan lengkap (dari /users/me → employee).
class EmployeeProfile {
  final String id;
  final String nik;
  final String fullName;
  final String? phone;
  final String? address;
  final String? birthDate;
  final String? gender;
  final String? hireDate;
  final String employmentStatus;
  final String? contractEndDate;
  final String? photoUrl;
  final String? bankName;
  final String? bankAccountNumber;
  final String? npwp;
  final String? bpjsKesehatan;
  final String? bpjsTk;
  final String? departmentName;
  final String? positionName;
  final String? supervisorName;
  final String? supervisorId;

  const EmployeeProfile({
    required this.id,
    required this.nik,
    required this.fullName,
    this.phone,
    this.address,
    this.birthDate,
    this.gender,
    this.hireDate,
    this.employmentStatus = 'permanent',
    this.contractEndDate,
    this.photoUrl,
    this.bankName,
    this.bankAccountNumber,
    this.npwp,
    this.bpjsKesehatan,
    this.bpjsTk,
    this.departmentName,
    this.positionName,
    this.supervisorName,
    this.supervisorId,
  });

  /// Nomor rekening disensor: ****1234
  String get maskedBankAccount {
    final acc = bankAccountNumber ?? '';
    if (acc.length <= 4) return acc.isEmpty ? '-' : acc;
    return '****${acc.substring(acc.length - 4)}';
  }

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) => EmployeeProfile(
        id: json['id'] as String,
        nik: toStr(json['nik']) ?? '',
        fullName: toStr(json['fullName']) ?? '',
        phone: toStr(json['phone']),
        address: toStr(json['address']),
        birthDate: toStr(json['birthDate']),
        gender: toStr(json['gender']),
        hireDate: toStr(json['hireDate']),
        employmentStatus: toStr(json['employmentStatus']) ?? 'permanent',
        contractEndDate: toStr(json['contractEndDate']),
        photoUrl: toStr(json['photoUrl']),
        bankName: toStr(json['bankName']),
        bankAccountNumber: toStr(json['bankAccountNumber']),
        npwp: toStr(json['npwp']),
        bpjsKesehatan: toStr(json['bpjsKesehatan']),
        bpjsTk: toStr(json['bpjsTk']),
        departmentName: json['department'] is Map ? toStr(json['department']['name']) : null,
        positionName: json['position'] is Map ? toStr(json['position']['name']) : null,
        supervisorName: json['supervisor'] is Map ? toStr(json['supervisor']['fullName']) : null,
        supervisorId: toStr(json['supervisorId']),
      );
}

/// Item karyawan ringkas dari GET /employees (untuk SPV melihat tim).
class TeamMember {
  final String id;
  final String nik;
  final String fullName;
  final String? photoUrl;
  final String? positionName;
  final String? supervisorId;

  const TeamMember({
    required this.id,
    required this.nik,
    required this.fullName,
    this.photoUrl,
    this.positionName,
    this.supervisorId,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: json['id'] as String,
        nik: toStr(json['nik']) ?? '',
        fullName: toStr(json['fullName']) ?? '',
        photoUrl: toStr(json['photoUrl']),
        positionName: json['position'] is Map ? toStr(json['position']['name']) : null,
        supervisorId: toStr(json['supervisorId']),
      );
}
