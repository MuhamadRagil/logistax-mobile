import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loading berbentuk daftar kartu.
class LoadingShimmer extends StatelessWidget {
  final int count;
  final double height;

  const LoadingShimmer({super.key, this.count = 3, this.height = 84});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Column(
        children: List.generate(
          count,
          (_) => Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
