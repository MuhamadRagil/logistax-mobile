import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/storage/session_prefs.dart';
import '../../../intern/intern_config.dart';
import '../../../intern/providers/intern_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/trial_reminder_dialog.dart';
import '../../providers/auth_provider.dart';

/// Halaman login: email + password, plus login biometrik bila sesi
/// sebelumnya masih tersimpan. Redirect sukses ditangani GoRouter.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  /// Email sesi terakhir — non-null berarti tombol biometrik ditampilkan.
  String? _bioEmail;

  /// Mode login (Karyawan/Magang). Toggle hanya tampil bila backend magang
  /// dikonfigurasi; tanpa itu layar ini identik dengan versi karyawan saja.
  SessionKind _mode = SessionKind.hr;

  bool get _isIntern => _mode == SessionKind.intern;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _loadMode();
  }

  Future<void> _loadMode() async {
    if (!InternConfig.isConfigured) return;
    final mode = await SessionPrefs.loginMode();
    if (mounted && mode != _mode) setState(() => _mode = mode);
  }

  void _setMode(SessionKind mode) {
    setState(() {
      _mode = mode;
      _error = null;
    });
    SessionPrefs.setLoginMode(mode);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('last_email');
      if (email == null || email.isEmpty) return;

      final token = await SecureStorage.getAccessToken();
      if (token == null) return;

      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final supported = await localAuth.isDeviceSupported();
      if (!canCheck && !supported) return;

      if (!mounted) return;
      setState(() => _bioEmail = email);
    } catch (_) {
      // Perangkat/emulator tanpa biometrik → tombol tidak ditampilkan.
    }
  }

  Future<void> _biometricLogin() async {
    try {
      final didAuth = await LocalAuthentication().authenticate(
        localizedReason: 'Masuk ke Logistax',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!didAuth) return;

      final ok = await ref.read(authControllerProvider).resumeSession();
      if (ok) await SessionPrefs.setLastActive(SessionKind.hr);
      if (!mounted) return;
      if (ok) {
        // Router akan redirect otomatis; go('/') untuk memastikan.
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi kedaluwarsa, silakan login manual'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } on PlatformException {
      if (mounted) setState(() => _bioEmail = null);
    } catch (_) {
      if (mounted) setState(() => _bioEmail = null);
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email dan password wajib diisi');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Format email tidak valid');
      return;
    }

    if (_isIntern) {
      await _submitIntern(email, password);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).login(email, password);
      await SessionPrefs.setLastActive(SessionKind.hr);
      // Router sudah mengalihkan halaman saat status berubah, jadi dialog
      // dipasang di navigator root — context halaman ini bisa sudah tidak ada.
      final rootContext = rootNavigatorKey.currentContext;
      // ignore: use_build_context_synchronously
      if (rootContext != null) await TrialReminderDialog.showIfNeeded(rootContext);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      final message = ApiException.fromDio(e).message;
      setState(() => _error = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Login ke backend magang. Sesi karyawan (bila tersimpan) tidak disentuh.
  Future<void> _submitIntern(String email, String password) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(internSessionProvider).login(email, password);
      // Router langsung pindah ke /intern — dialog dipasang di navigator root.
      final rootContext = rootNavigatorKey.currentContext;
      // ignore: use_build_context_synchronously
      if (rootContext != null) await TrialReminderDialog.showIfNeeded(rootContext);
    } catch (e) {
      if (!mounted) return;
      final message = ApiException.fromDio(e).message;
      setState(() => _error = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, AppColors.teal],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/logo-logistax-white.svg',
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'HR & Payroll System',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    // Kartu selalu terang meski app dark mode (dibungkus tema terang).
    return Theme(
      data: lightTheme(),
      child: Card(
        color: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Masuk ke Akun Anda',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyDark,
                ),
              ),
              if (InternConfig.isConfigured) ...[
                const SizedBox(height: 16),
                SegmentedButton<SessionKind>(
                  segments: const [
                    ButtonSegment(
                      value: SessionKind.hr,
                      label: Text('Karyawan'),
                      icon: Icon(Icons.badge_outlined),
                    ),
                    ButtonSegment(
                      value: SessionKind.intern,
                      label: Text('Magang'),
                      icon: Icon(Icons.school_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _loading ? null : (s) => _setMode(s.first),
                ),
              ],
              const SizedBox(height: 20),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: _isIntern ? 'email akun magang' : 'nama@perusahaan.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Password Anda',
                obscure: _obscurePassword,
                prefixIcon: Icons.lock_outline,
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              // Lupa password hanya untuk akun karyawan (backend magang tidak
              // menyediakan reset password).
              if (!_isIntern)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot'),
                    child: const Text('Lupa Password?'),
                  ),
                )
              else
                const SizedBox(height: 16),
              const SizedBox(height: 4),
              AppButton(
                label: 'Masuk',
                loading: _loading,
                onPressed: _submit,
              ),
              if (_bioEmail != null && !_isIntern) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _biometricLogin,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(
                    'Masuk dengan Biometrik ($_bioEmail)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
