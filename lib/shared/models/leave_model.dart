import 'model_utils.dart';

class LeaveType {
  final String id;
  final String name;
  final int defaultDaysPerYear;
  final bool isPaid;
  final bool requiresDocument;

  const LeaveType({
    required this.id,
    required this.name,
    this.defaultDaysPerYear = 0,
    this.isPaid = true,
    this.requiresDocument = false,
  });

  factory LeaveType.fromJson(Map<String, dynamic> json) => LeaveType(
        id: json['id'] as String,
        name: toStr(json['name']) ?? '',
        defaultDaysPerYear: toInt(json['defaultDaysPerYear']),
        isPaid: json['isPaid'] == true,
        requiresDocument: json['requiresDocument'] == true,
      );
}

class LeaveBalance {
  final String id;
  final String leaveTypeId;
  final String leaveTypeName;
  final int year;
  final int totalDays;
  final int usedDays;
  final int carryOverDays;

  const LeaveBalance({
    required this.id,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.year,
    this.totalDays = 0,
    this.usedDays = 0,
    this.carryOverDays = 0,
  });

  int get quota => totalDays + carryOverDays;
  int get remaining => quota - usedDays;

  factory LeaveBalance.fromJson(Map<String, dynamic> json) => LeaveBalance(
        id: json['id'] as String,
        leaveTypeId: toStr(json['leaveTypeId']) ?? '',
        leaveTypeName: json['leaveType'] is Map ? (toStr(json['leaveType']['name']) ?? '') : '',
        year: toInt(json['year']),
        totalDays: toInt(json['totalDays']),
        usedDays: toInt(json['usedDays']),
        carryOverDays: toInt(json['carryOverDays']),
      );
}

class LeaveRequest {
  final String id;
  final String employeeId;
  final String leaveTypeId;
  final String? leaveTypeName;
  final String startDate;
  final String endDate;
  final int totalDays;
  final String reason;
  final String? documentUrl;
  final String status; // pending|approved|rejected|cancelled
  final String? rejectionReason;
  final String? createdAt;
  final String? employeeName;
  final String? departmentName;

  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.leaveTypeId,
    this.leaveTypeName,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    this.documentUrl,
    required this.status,
    this.rejectionReason,
    this.createdAt,
    this.employeeName,
    this.departmentName,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
        id: json['id'] as String,
        employeeId: toStr(json['employeeId']) ?? '',
        leaveTypeId: toStr(json['leaveTypeId']) ?? '',
        leaveTypeName: json['leaveType'] is Map ? toStr(json['leaveType']['name']) : null,
        startDate: toStr(json['startDate']) ?? '',
        endDate: toStr(json['endDate']) ?? '',
        totalDays: toInt(json['totalDays']),
        reason: toStr(json['reason']) ?? '',
        documentUrl: toStr(json['documentUrl']),
        status: toStr(json['status']) ?? 'pending',
        rejectionReason: toStr(json['rejectionReason']),
        createdAt: toStr(json['createdAt']),
        employeeName: json['employee'] is Map ? toStr(json['employee']['fullName']) : null,
        departmentName: json['employee'] is Map && json['employee']['department'] is Map
            ? toStr(json['employee']['department']['name'])
            : null,
      );
}
