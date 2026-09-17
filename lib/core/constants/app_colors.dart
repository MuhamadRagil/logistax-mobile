import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const navy = Color(0xFF003087);
  static const navyDark = Color(0xFF001B50);
  static const teal = Color(0xFF00A6C0);
  static const tealLight = Color(0xFFE0F6FA);
  static const white = Colors.white;

  // Light theme neutrals
  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const border = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const inactiveIcon = Color(0xFF9CA3AF);

  // Semantic
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Attendance status
  static const present = Color(0xFF10B981);
  static const late = Color(0xFFF59E0B);
  static const absent = Color(0xFFEF4444);
  static const leave = Color(0xFF8B5CF6);
  static const holiday = Color(0xFF9CA3AF);
  static const wfh = Color(0xFF06B6D4);
  static const sick = Color(0xFF3B82F6);

  /// Warna per status absensi (present/late/absent/sick/izin/cuti/wfh/holiday).
  static Color attendanceStatus(String? status) {
    switch (status) {
      case 'present':
        return present;
      case 'late':
        return late;
      case 'absent':
        return absent;
      case 'sick':
        return sick;
      case 'izin':
        return leave;
      case 'cuti':
        return leave;
      case 'wfh':
        return wfh;
      case 'holiday':
        return holiday;
      default:
        return holiday;
    }
  }

  /// Warna per tier KPI.
  static Color kpiTier(String? tier) {
    switch (tier) {
      case 'excellent':
        return success;
      case 'good':
        return info;
      case 'average':
        return warning;
      case 'below_average':
        return const Color(0xFFF97316);
      case 'poor':
        return error;
      default:
        return holiday;
    }
  }
}
