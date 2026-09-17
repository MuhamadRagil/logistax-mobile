import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Logo teks "LOGISTAX" — X selalu teal.
class LogistaxLogo extends StatelessWidget {
  final double fontSize;
  final Color color;

  const LogistaxLogo({super.key, this.fontSize = 28, this.color = AppColors.navy});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(fontSize * 0.22),
          decoration: BoxDecoration(
            color: color == Colors.white ? Colors.white : AppColors.navy,
            borderRadius: BorderRadius.circular(fontSize * 0.28),
          ),
          child: Icon(Icons.bolt_rounded, color: AppColors.teal, size: fontSize * 0.9),
        ),
        SizedBox(width: fontSize * 0.35),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'LOGISTA', style: TextStyle(color: color)),
              const TextSpan(text: 'X', style: TextStyle(color: AppColors.teal)),
            ],
          ),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
