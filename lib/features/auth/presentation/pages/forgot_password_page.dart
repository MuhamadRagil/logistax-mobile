import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/auth_repository.dart';

/// Halaman lupa password: kirim tautan reset ke email.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailController = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Masukkan email yang valid');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthRepository().forgotPassword(email);
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiException.fromDio(e).message);
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
          child: _sent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Lupa Password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navyDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan email Anda, kami akan mengirim tautan untuk mengatur ulang password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'nama@perusahaan.com',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'Kirim Tautan Reset',
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read, color: AppColors.teal, size: 56),
        const SizedBox(height: 16),
        const Text(
          'Jika email terdaftar, tautan reset telah dikirim. Cek email Anda.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.navyDark),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Kembali ke Login',
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
