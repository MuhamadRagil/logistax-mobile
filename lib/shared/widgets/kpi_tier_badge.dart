import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import 'status_badge.dart';

class KpiTierBadge extends StatelessWidget {
  final String? tier;
  final double fontSize;

  const KpiTierBadge({super.key, required this.tier, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    if (tier == null) {
      return StatusBadge(label: 'Belum dinilai', color: AppColors.holiday, fontSize: fontSize);
    }
    return StatusBadge(
      label: AppStrings.kpiTierLabel[tier] ?? tier!,
      color: AppColors.kpiTier(tier),
      fontSize: fontSize,
    );
  }
}
