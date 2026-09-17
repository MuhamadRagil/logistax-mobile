import 'model_utils.dart';

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String date;
  final String? checkInTime;
  final String? checkOutTime;
  final String status; // present|late|absent|sick|izin|cuti|wfh|holiday
  final int lateMinutes;
  final String? notes;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.lateMinutes = 0,
    this.notes,
  });

  bool get hasCheckedIn => checkInTime != null;
  bool get hasCheckedOut => checkOutTime != null;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'] as String,
        employeeId: toStr(json['employeeId']) ?? '',
        date: toStr(json['date']) ?? '',
        checkInTime: toStr(json['checkInTime']),
        checkOutTime: toStr(json['checkOutTime']),
        status: toStr(json['status']) ?? 'absent',
        lateMinutes: toInt(json['lateMinutes']),
        notes: toStr(json['notes']),
      );
}

/// Response GET /settings/attendance — dipakai halaman absensi tombol GPS
/// untuk tahu titik kantor dan radius yang diizinkan.
class AttendanceSettings {
  final String workStartTime; // "09:00"
  final String workEndTime; // "17:00"
  final int lateToleranceMinutes;
  final double officeLatitude;
  final double officeLongitude;
  final int gpsRadiusMeters;

  const AttendanceSettings({
    required this.workStartTime,
    required this.workEndTime,
    required this.lateToleranceMinutes,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.gpsRadiusMeters,
  });

  factory AttendanceSettings.fromJson(Map<String, dynamic> json) => AttendanceSettings(
        workStartTime: toStr(json['workStartTime']) ?? '-',
        workEndTime: toStr(json['workEndTime']) ?? '-',
        lateToleranceMinutes: toInt(json['lateToleranceMinutes']),
        officeLatitude: toDouble(json['officeLatitude']),
        officeLongitude: toDouble(json['officeLongitude']),
        gpsRadiusMeters: toInt(json['gpsRadiusMeters']),
      );
}

class AttendanceSummary {
  final int present;
  final int late;
  final int absent;
  final int sick;
  final int izin;
  final int cuti;
  final int wfh;
  final int holiday;
  final int lateMinutesTotal;

  const AttendanceSummary({
    this.present = 0,
    this.late = 0,
    this.absent = 0,
    this.sick = 0,
    this.izin = 0,
    this.cuti = 0,
    this.wfh = 0,
    this.holiday = 0,
    this.lateMinutesTotal = 0,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) => AttendanceSummary(
        present: toInt(json['present']),
        late: toInt(json['late']),
        absent: toInt(json['absent']),
        sick: toInt(json['sick']),
        izin: toInt(json['izin']),
        cuti: toInt(json['cuti']),
        wfh: toInt(json['wfh']),
        holiday: toInt(json['holiday']),
        lateMinutesTotal: toInt(json['lateMinutesTotal']),
      );
}

/// Response GET /attendance/monthly (records terisi hanya saat filter satu employeeId).
class AttendanceMonthly {
  final int year;
  final int month;
  final int workingDays;
  final List<AttendanceMonthlyEmployee> employees;

  const AttendanceMonthly({
    required this.year,
    required this.month,
    required this.workingDays,
    required this.employees,
  });

  factory AttendanceMonthly.fromJson(Map<String, dynamic> json) => AttendanceMonthly(
        year: toInt(json['period']?['year']),
        month: toInt(json['period']?['month']),
        workingDays: toInt(json['workingDays']),
        employees: (json['employees'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AttendanceMonthlyEmployee.fromJson)
            .toList(),
      );
}

class AttendanceMonthlyEmployee {
  final String employeeId;
  final String fullName;
  final String? photoUrl;
  final AttendanceSummary summary;
  final List<AttendanceRecord> records;

  const AttendanceMonthlyEmployee({
    required this.employeeId,
    required this.fullName,
    this.photoUrl,
    required this.summary,
    required this.records,
  });

  factory AttendanceMonthlyEmployee.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] as Map<String, dynamic>? ?? {};
    return AttendanceMonthlyEmployee(
      employeeId: toStr(emp['id']) ?? '',
      fullName: toStr(emp['fullName']) ?? '',
      photoUrl: toStr(emp['photoUrl']),
      summary: AttendanceSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      records: (json['records'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AttendanceRecord.fromJson)
          .toList(),
    );
  }
}

/// Item dari GET /attendance/today (hrd/spv) — untuk halaman tim SPV.
class TodayBoardItem {
  final String employeeId;
  final String nik;
  final String fullName;
  final String? photoUrl;
  final String? positionName;
  final String? status; // null / unknown = belum absen
  final AttendanceRecord? record;

  const TodayBoardItem({
    required this.employeeId,
    required this.nik,
    required this.fullName,
    this.photoUrl,
    this.positionName,
    this.status,
    this.record,
  });

  factory TodayBoardItem.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] as Map<String, dynamic>? ?? {};
    return TodayBoardItem(
      employeeId: toStr(emp['id']) ?? '',
      nik: toStr(emp['nik']) ?? '',
      fullName: toStr(emp['fullName']) ?? '',
      photoUrl: toStr(emp['photoUrl']),
      positionName: emp['position'] is Map ? toStr(emp['position']['name']) : null,
      status: toStr(json['status']),
      record: json['record'] is Map<String, dynamic>
          ? AttendanceRecord.fromJson(json['record'] as Map<String, dynamic>)
          : null,
    );
  }
}
