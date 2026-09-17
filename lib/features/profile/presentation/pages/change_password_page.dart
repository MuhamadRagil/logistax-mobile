import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/data/auth_repository.dart';

/// Ubah password akun (POST /auth/change-password).
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await AuthRepository().changePassword(_current.text, _newPass.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 42),
          title: const Text('Password berhasil diubah'),
          content: const Text('Gunakan password baru Anda saat masuk berikutnya.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.pop();
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

  Widget _eye(bool obscured, VoidCallback onToggle) => IconButton(
        icon: Icon(obscured ? Icons.visibility_rounded : Icons.visibility_off_rounded),
        onPressed: onToggle,
        tooltip: obscured ? 'Tampilkan' : 'Sembunyikan',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _current,
              label: 'Password Saat Ini',
              hint: 'Masukkan password Anda sekarang',
              obscure: _obscureCurrent,
              prefixIcon: Icons.lock_outline_rounded,
              suffix: _eye(
                _obscureCurrent,
                () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password saat ini wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _newPass,
              label: 'Password Baru',
              hint: 'Minimal 8 karakter',
              obscure: _obscureNew,
              prefixIcon: Icons.lock_reset_rounded,
              suffix: _eye(_obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password baru wajib diisi';
                if (v.length < 8) return 'Password baru minimal 8 karakter';
                if (v == _current.text) return 'Password baru harus berbeda dari yang lama';
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirm,
              label: 'Konfirmasi Password Baru',
              hint: 'Ulangi password baru',
              obscure: _obscureConfirm,
              prefixIcon: Icons.lock_person_rounded,
              suffix: _eye(
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Konfirmasi password wajib diisi';
                if (v != _newPass.text) return 'Konfirmasi password tidak cocok';
                return null;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Simpan',
                icon: Icons.save_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
