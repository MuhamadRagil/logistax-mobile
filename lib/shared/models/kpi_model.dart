import 'model_utils.dart';

class KpiSummary {
  final String id;
  final String employeeId;
  final int periodYear;
  final int periodMonth;
  final double totalScore;
  final String tier; // excellent|good|average|below_average|poor
  final int rankInCompany;
  final bool isEmployeeOfMonth;
  final String? employeeName;
  final String? photoUrl;
  final String? departmentName;
  final String? positionName;

  const KpiSummary({
    required this.id,
    required this.employeeId,
    required this.periodYear,
    required this.periodMonth,
    required this.totalScore,
    required this.tier,
    this.rankInCompany = 0,
    this.isEmployeeOfMonth = false,
    this.employeeName,
    this.photoUrl,
    this.departmentName,
    this.positionName,
  });

  factory KpiSummary.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] as Map<String, dynamic>? ?? {};
    return KpiSummary(
      id: toStr(json['id']) ?? '',
      employeeId: toStr(json['employeeId']) ?? '',
      periodYear: toInt(json['periodYear']),
      periodMonth: toInt(json['periodMonth']),
      totalScore: toDouble(json['totalScore']),
      tier: toStr(json['tier']) ?? 'average',
      rankInCompany: toInt(json['rankInCompany']),
      isEmployeeOfMonth: json['isEmployeeOfMonth'] == true,
      employeeName: toStr(emp['fullName']),
      photoUrl: toStr(emp['photoUrl']),
      departmentName: emp['department'] is Map ? toStr(emp['department']['name']) : null,
      positionName: emp['position'] is Map ? toStr(emp['position']['name']) : null,
    );
  }
}

/// GET /kpi/monthly → leaderboard perusahaan (employee: hanya setelah finalized).
class KpiMonthly {
  final int year;
  final int month;
  final String monthName;
  final bool finalized;
  final KpiSummary? employeeOfTheMonth;
  final List<KpiSummary> leaderboard;

  const KpiMonthly({
    required this.year,
    required this.month,
    this.monthName = '',
    this.finalized = false,
    this.employeeOfTheMonth,
    this.leaderboard = const [],
  });

  factory KpiMonthly.fromJson(Map<String, dynamic> json) => KpiMonthly(
        year: toInt(json['period']?['year']),
        month: toInt(json['period']?['month']),
        monthName: toStr(json['period']?['monthName']) ?? '',
        finalized: json['finalized'] == true,
        employeeOfTheMonth: json['employeeOfTheMonth'] is Map<String, dynamic>
            ? KpiSummary.fromJson(json['employeeOfTheMonth'] as Map<String, dynamic>)
            : null,
        leaderboard: (json['leaderboard'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(KpiSummary.fromJson)
            .toList(),
      );
}

class KpiBreakdownItem {
  final String categoryName;
  final bool isAutoCalculated;
  final double weightPct;
  final double rawScore;
  final double weightedScore;
  final String? notes;

  const KpiBreakdownItem({
    required this.categoryName,
    this.isAutoCalculated = false,
    required this.weightPct,
    required this.rawScore,
    required this.weightedScore,
    this.notes,
  });

  factory KpiBreakdownItem.fromJson(Map<String, dynamic> json) => KpiBreakdownItem(
        categoryName: json['category'] is Map ? (toStr(json['category']['name']) ?? '') : '',
        isAutoCalculated: json['category'] is Map && json['category']['isAutoCalculated'] == true,
        weightPct: toDouble(json['weightPct']),
        rawScore: toDouble(json['rawScore']),
        weightedScore: toDouble(json['weightedScore']),
        notes: toStr(json['notes']),
      );
}

class KpiTrendPoint {
  final int year;
  final int month;
  final double totalScore;
  final String tier;
  final int rankInCompany;

  const KpiTrendPoint({
    required this.year,
    required this.month,
    required this.totalScore,
    required this.tier,
    this.rankInCompany = 0,
  });

  factory KpiTrendPoint.fromJson(Map<String, dynamic> json) => KpiTrendPoint(
        year: toInt(json['year']),
        month: toInt(json['month']),
        totalScore: toDouble(json['totalScore']),
        tier: toStr(json['tier']) ?? 'average',
        rankInCompany: toInt(json['rankInCompany']),
      );
}

/// GET /kpi/employee/:id → detail KPI saya.
class KpiEmployeeDetail {
  final int year;
  final int month;
  final String monthName;
  final List<KpiBreakdownItem> breakdown;
  final KpiSummary? summary;
  final List<KpiTrendPoint> trend;

  const KpiEmployeeDetail({
    required this.year,
    required this.month,
    this.monthName = '',
    this.breakdown = const [],
    this.summary,
    this.trend = const [],
  });

  factory KpiEmployeeDetail.fromJson(Map<String, dynamic> json) => KpiEmployeeDetail(
        year: toInt(json['period']?['year']),
        month: toInt(json['period']?['month']),
        monthName: toStr(json['period']?['monthName']) ?? '',
        breakdown: (json['breakdown'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(KpiBreakdownItem.fromJson)
            .toList(),
        summary: json['summary'] is Map<String, dynamic>
            ? KpiSummary.fromJson(json['summary'] as Map<String, dynamic>)
            : null,
        trend: (json['trend'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(KpiTrendPoint.fromJson)
            .toList(),
      );
}
