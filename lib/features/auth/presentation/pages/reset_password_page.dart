import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/auth_repository.dart';

/// Halaman reset password. Mobile tidak punya deeplink, jadi token
/// bisa di-paste manual dari email (prefilled bila dikirim via query).
class ResetPasswordPage extends ConsumerStatefulWidget {
  final String? token;

  const ResetPasswordPage({super.key, this.token});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  late final TextEditingController _tokenController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _passwordError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.token ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    final token = _tokenController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    String? passwordError;
    String? confirmError;

    if (password.length < 8) {
      passwordError = 'Password minimal 8 karakter';
    }
    if (confirm != password) {
      confirmError = 'Konfirmasi password tidak cocok';
    }

    setState(() {
      _passwordError = passwordError;
      _confirmError = confirmError;
    });

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token reset wajib diisi'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    return passwordError == null && confirmError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _loading = true);
    try {
      await AuthRepository().resetPassword(
        _tokenController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
          title: const Text('Password Diperbarui'),
          content: const Text(
            'Password Anda berhasil diubah. Silakan login dengan password baru.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiException.fromDio(e).message),
          backgroundColor: AppColors.error,
        ),
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
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.go('/login'),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: _buildCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    // Kartu selalu terang meski app dark mode.
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
                'Atur Ulang Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tempel token dari email Anda, lalu buat password baru.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _tokenController,
                label: 'Token Reset',
                hint: 'Tempel token dari email',
                prefixIcon: Icons.vpn_key_outlined,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _passwordController,
                label: 'Password Baru',
                hint: 'Minimal 8 karakter',
                obscure: _obscurePassword,
                prefixIcon: Icons.lock_outline,
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
              if (_passwordError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _passwordError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                controller: _confirmController,
                label: 'Konfirmasi Password',
                hint: 'Ulangi password baru',
                obscure: _obscureConfirm,
                prefixIcon: Icons.lock_outline,
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              if (_confirmError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _confirmError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: 'Simpan Password Baru',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
