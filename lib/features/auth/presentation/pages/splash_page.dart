import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/widgets/trial_reminder_dialog.dart';
import '../../../intern/providers/intern_session.dart';
import '../../providers/auth_provider.dart';

/// Splash: logo fade-in + cek sesi. Redirect ditangani GoRouter
/// begitu AuthController mengubah status.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => _visible = true);
      try {
        final auth = ref.read(authControllerProvider);
        // Diambil sebelum await: saat router berpindah halaman, splash sudah
        // dispose dan `ref` tidak boleh dipakai lagi.
        final intern = ref.read(internSessionProvider);
        if (auth.status == AuthStatus.unknown) {
          // Tanpa token intern tersimpan, shouldRestoreFirst() selalu false →
          // alur karyawan identik dengan sebelumnya.
          if (await intern.shouldRestoreFirst()) {
            // Samakan durasi splash dengan alur karyawan (min. 1,4 detik).
            await Future.delayed(const Duration(milliseconds: 1400));
            if (await intern.restore()) {
              auth.skipSessionCheck();
            } else {
              await auth.init();
            }
          } else {
            await auth.init();
            // Sesi karyawan tidak valid tapi sesi intern tersimpan → pakai itu.
            if (auth.status == AuthStatus.unauthenticated) await intern.restore();
          }
        }
        if (auth.status == AuthStatus.authenticated || intern.isActive) {
          // Router segera mengganti splash → home, jadi dialog dipasang di
          // navigator root (bukan context splash) setelah frame berikutnya.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final rootContext = rootNavigatorKey.currentContext;
            if (rootContext != null) TrialReminderDialog.showIfNeeded(rootContext);
          });
        }
      } catch (_) {
        // Jaring pengaman terakhir — auth.init() sendiri sudah menangkap
        // error validasi sesi, ini hanya untuk kegagalan tak terduga
        // (mis. SecureStorage.clear() ikut gagal di dalamnya).
        try {
          await SecureStorage.clear();
        } catch (_) {
          // storage benar-benar tidak bisa diakses — abaikan, tetap lanjut ke login
        }
        if (mounted) context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, AppColors.teal],
          ),
        ),
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 1200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/logo-logistax-white.svg',
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                Text(
                  'HR & Payroll System',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
