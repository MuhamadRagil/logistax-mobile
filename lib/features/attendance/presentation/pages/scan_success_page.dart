import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../providers/attendance_provider.dart';

/// Konfirmasi absensi berhasil — otomatis kembali ke beranda setelah 3 detik.
class ScanSuccessPage extends ConsumerStatefulWidget {
  const ScanSuccessPage({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  ConsumerState<ScanSuccessPage> createState() => _ScanSuccessPageState();
}

class _ScanSuccessPageState extends ConsumerState<ScanSuccessPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _animController,
    curve: Curves.elasticOut,
  );

  Timer? _redirectTimer;

  Map<String, dynamic> get _record {
    final raw = widget.result['record'];
    return raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};
  }

  bool get _isCheckIn => widget.result['type'] != 'checkout';

  @override
  void initState() {
    super.initState();
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(myTodayProvider);
    });

    _redirectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      context.go('/');
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = _record;

    final status = record['status'] as String?;
    final lateMinutes = (record['lateMinutes'] as num?)?.toInt() ?? 0;
    final isLate = status == 'late';

    final timeValue = _isCheckIn
        ? (record['checkInTime'] ?? record['checkOutTime'])
        : (record['checkOutTime'] ?? record['checkInTime']);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Centang animasi
              ScaleTransition(
                scale: _scale,
                child: Container(
                  height: 168,
                  width: 168,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.teal, AppColors.success],
                    ),
                  ),
                  child: const Icon(Icons.check_rounded, size: 96, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                _isCheckIn ? 'Check-In Berhasil!' : 'Check-Out Berhasil!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              Text(
                formatTimeWib(timeValue),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),

              if (isLate)
                StatusBadge(
                  label: 'Terlambat $lateMinutes menit',
                  color: AppColors.warning,
                  fontSize: 14,
                )
              else
                const StatusBadge(
                  label: 'Tepat Waktu',
                  color: AppColors.success,
                  fontSize: 14,
                ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Kembali ke Beranda',
                  icon: Icons.home_rounded,
                  onPressed: () => context.go('/'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Otomatis kembali dalam beberapa detik...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
