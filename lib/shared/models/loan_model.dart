import 'model_utils.dart';

class EmployeeLoan {
  final String id;
  final num totalAmount;
  final num remainingAmount;
  final num monthlyInstallment;
  final String? purpose;
  final String status; // active|completed|cancelled
  final int startYear;
  final int startMonth;
  final String? notes;

  const EmployeeLoan({
    required this.id,
    required this.totalAmount,
    required this.remainingAmount,
    required this.monthlyInstallment,
    this.purpose,
    required this.status,
    required this.startYear,
    required this.startMonth,
    this.notes,
  });

  num get paidAmount => totalAmount - remainingAmount;
  double get progressPct => totalAmount > 0 ? (paidAmount / totalAmount * 100).toDouble() : 0;
  int get paidInstallments =>
      monthlyInstallment > 0 ? (paidAmount / monthlyInstallment).round() : 0;
  int get totalInstallments =>
      monthlyInstallment > 0 ? (totalAmount / monthlyInstallment).ceil() : 0;
  int get remainingMonths =>
      monthlyInstallment > 0 ? (remainingAmount / monthlyInstallment).ceil() : 0;

  factory EmployeeLoan.fromJson(Map<String, dynamic> json) => EmployeeLoan(
        id: json['id'] as String,
        totalAmount: toNum(json['totalAmount']),
        remainingAmount: toNum(json['remainingAmount']),
        monthlyInstallment: toNum(json['monthlyInstallment']),
        purpose: toStr(json['purpose']),
        status: toStr(json['status']) ?? 'active',
        startYear: toInt(json['startYear']),
        startMonth: toInt(json['startMonth']),
        notes: toStr(json['notes']),
      );
}
