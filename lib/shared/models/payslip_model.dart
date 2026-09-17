import 'model_utils.dart';

class Payslip {
  final String id;
  final String payrollRunId;
  final int periodYear;
  final int periodMonth;
  final int workingDays;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int leaveDays;
  final num gajiPokok;
  final num tunjangan;
  final num lembur;
  final num transport;
  final num bonusThr;
  final num totalPenerimaan;
  final num pinjamanKaryawan;
  final num potonganAbsen;
  final num pph21Karyawan;
  final num bpjsKaryawan;
  final num totalPotongan;
  final num takeHomePay;
  final String terbilang;
  final String? employeeName;
  final String? nik;
  final String? positionName;
  final String? departmentName;

  const Payslip({
    required this.id,
    required this.payrollRunId,
    required this.periodYear,
    required this.periodMonth,
    this.workingDays = 0,
    this.presentDays = 0,
    this.lateDays = 0,
    this.absentDays = 0,
    this.leaveDays = 0,
    this.gajiPokok = 0,
    this.tunjangan = 0,
    this.lembur = 0,
    this.transport = 0,
    this.bonusThr = 0,
    this.totalPenerimaan = 0,
    this.pinjamanKaryawan = 0,
    this.potonganAbsen = 0,
    this.pph21Karyawan = 0,
    this.bpjsKaryawan = 0,
    this.totalPotongan = 0,
    this.takeHomePay = 0,
    this.terbilang = '',
    this.employeeName,
    this.nik,
    this.positionName,
    this.departmentName,
  });

  /// Password PDF: 6 digit terakhir NIK (angka saja). LMS.01025 → 001025... sesuai backend.
  String get pdfPasswordHint {
    final digits = (nik ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '6 digit terakhir No. ID Anda';
    final last6 = digits.length >= 6 ? digits.substring(digits.length - 6) : digits.padLeft(6, '0');
    return last6;
  }

  factory Payslip.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] as Map<String, dynamic>? ?? {};
    return Payslip(
      id: json['id'] as String,
      payrollRunId: toStr(json['payrollRunId']) ?? '',
      periodYear: toInt(json['periodYear']),
      periodMonth: toInt(json['periodMonth']),
      workingDays: toInt(json['workingDays']),
      presentDays: toInt(json['presentDays']),
      lateDays: toInt(json['lateDays']),
      absentDays: toInt(json['absentDays']),
      leaveDays: toInt(json['leaveDays']),
      gajiPokok: toNum(json['gajiPokok']),
      tunjangan: toNum(json['tunjangan']),
      lembur: toNum(json['lembur']),
      transport: toNum(json['transport']),
      bonusThr: toNum(json['bonusThr']),
      totalPenerimaan: toNum(json['totalPenerimaan']),
      pinjamanKaryawan: toNum(json['pinjamanKaryawan']),
      potonganAbsen: toNum(json['potonganAbsen']),
      pph21Karyawan: toNum(json['pph21Karyawan']),
      bpjsKaryawan: toNum(json['bpjsKaryawan']),
      totalPotongan: toNum(json['totalPotongan']),
      takeHomePay: toNum(json['takeHomePay']),
      terbilang: toStr(json['terbilang']) ?? '',
      employeeName: toStr(emp['fullName']),
      nik: toStr(emp['nik']),
      positionName: emp['position'] is Map ? toStr(emp['position']['name']) : null,
      departmentName: emp['department'] is Map ? toStr(emp['department']['name']) : null,
    );
  }
}
