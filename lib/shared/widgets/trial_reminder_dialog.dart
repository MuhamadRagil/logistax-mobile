import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_util.dart';

final kTrialStart = DateTime(2026, 9, 25);
final kTrialEnd = DateTime(2026, 10, 5);

const _kOrange = Color(0xFFEA580C);

enum TrialPhase { notStarted, active, expired }

class TrialStatus {
  const TrialStatus(this.phase, this.remainingDays);

  final TrialPhase phase;
  final int remainingDays;

  /// Dibandingkan per tanggal (bukan jam) dan lewat UTC agar selisih hari
  /// tidak melenceng oleh zona waktu/DST. Tanggal berakhir termasuk masa
  /// trial (sisa 0 hari), baru terblokir sehari setelahnya.
  static TrialStatus of(DateTime now) {
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = DateTime.utc(kTrialStart.year, kTrialStart.month, kTrialStart.day);
    final end = DateTime.utc(kTrialEnd.year, kTrialEnd.month, kTrialEnd.day);

    if (today.isBefore(start)) return const TrialStatus(TrialPhase.notStarted, 0);
    if (today.isAfter(end)) return const TrialStatus(TrialPhase.expired, 0);
    return TrialStatus(TrialPhase.active, end.difference(today).inDays);
  }
}

/// Popup pengingat sisa masa trial. Ditampilkan hanya selama masa trial aktif.
class TrialReminderDialog extends StatelessWidget {
  const TrialReminderDialog({super.key, required this.remainingDays});

  final int remainingDays;

  static Future<void> showIfNeeded(BuildContext context) async {
    final status = TrialStatus.of(DateTime.now());
    if (status.phase != TrialPhase.active) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TrialReminderDialog(remainingDays: status.remainingDays),
    );
  }

  Color get _daysColor {
    if (remainingDays <= 0) return AppColors.error;
    if (remainingDays <= 3) return _kOrange;
    return AppColors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time_filled_rounded, size: 34, color: _kOrange),
          ),
          const SizedBox(height: 18),
          Text(
            'Masa Trial Akan Berakhir',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Text(
            '$remainingDays Hari Lagi',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: _daysColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Berakhir ${formatDateLong(kTrialEnd)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Saya Mengerti'),
          ),
        ),
      ],
    );
  }
}

/// Layar penuh saat masa trial habis — tanpa tombol tutup.
class TrialBlockedScreen extends StatelessWidget {
  const TrialBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 88,
                    width: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_clock_rounded, size: 46, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Masa trial telah berakhir.\nHubungi administrator.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Membungkus seluruh app: bila masa trial habis, ganti isi app dengan
/// [TrialBlockedScreen]. Dicek ulang tiap app kembali dari background agar
/// app yang dibiarkan terbuka berhari-hari tetap terblokir.
class TrialGate extends StatefulWidget {
  const TrialGate({super.key, required this.child});

  final Widget child;

  @override
  State<TrialGate> createState() => _TrialGateState();
}

class _TrialGateState extends State<TrialGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (TrialStatus.of(DateTime.now()).phase == TrialPhase.expired) {
      return const TrialBlockedScreen();
    }
    return widget.child;
  }
}
