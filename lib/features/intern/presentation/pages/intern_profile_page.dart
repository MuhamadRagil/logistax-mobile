import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_util.dart';
import '../../providers/intern_session.dart';

/// Profil intern (read-only). Data berasal dari response login — backend
/// magang tidak punya endpoint profil untuk intern, jadi perubahan dari admin
/// (mis. perpanjangan periode) baru terlihat setelah login ulang.
class InternProfilePage extends ConsumerWidget {
  const InternProfilePage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun magang?'),
        content: const Text('Hanya sesi magang yang diakhiri. Anda perlu login lagi untuk masuk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Router otomatis mengarahkan ke /login setelah sesi intern berakhir.
    await ref.read(internSessionProvider).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(internSessionProvider).profile;
    final theme = Theme.of(context);
    if (profile == null) return const Scaffold();

    final photo = profile.photoUrl;
    final rows = [
      ('NIM', profile.nim),
      ('Institusi', profile.institution ?? '-'),
      ('Jurusan', profile.major ?? '-'),
      ('No. HP', profile.phone ?? '-'),
      ('Status', profile.statusLabel),
      ('Mulai', formatDateLong(profile.startDate)),
      ('Selesai', formatDateLong(profile.endDate)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Magang')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.tealLight,
              backgroundImage:
                  (photo != null && photo.isNotEmpty) ? CachedNetworkImageProvider(photo) : null,
              child: (photo != null && photo.isNotEmpty)
                  ? null
                  : const Icon(Icons.person, size: 44, color: AppColors.teal),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.fullName.isEmpty ? '-' : profile.fullName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              label,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              value.isEmpty ? '-' : value,
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Data diperbarui saat login. Jika admin mengubah data Anda, keluar lalu login kembali.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded, color: AppColors.teal),
                  title: const Text('Sertifikat'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/intern/sertifikat'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: const Text(
                    'Keluar',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
