import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/employee_model.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/logistax_app_bar.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

/// Halaman profil: identitas karyawan, data pokok, rekening, dan menu akun.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda harus masuk kembali untuk menggunakan aplikasi.'),
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
    // Router otomatis mengarahkan ke /login setelah status berubah.
    await ref.read(authControllerProvider).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myProfileProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: const LogistaxAppBar(title: 'Profil'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          await ref.read(myProfileProvider.future);
        },
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(count: 4, height: 110),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              ErrorState(error: error, onRetry: () => ref.invalidate(myProfileProvider)),
            ],
          ),
          data: (profile) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              if (profile == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: EmptyState(
                    icon: Icons.person_off_rounded,
                    title: 'Akun tidak terhubung dengan data karyawan',
                    description: 'Hubungi HRD untuk menghubungkan akun Anda.',
                  ),
                )
              else ...[
                _ProfileHeader(profile: profile),
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Data Karyawan',
                  rows: [
                    ('NIK', profile.nik.isEmpty ? '-' : profile.nik),
                    ('Email', auth.user?.email ?? '-'),
                    ('Telepon', profile.phone ?? '-'),
                    ('Tanggal Bergabung', formatDateLong(profile.hireDate)),
                    (
                      'Status Kepegawaian',
                      AppStrings.employmentStatusLabel[profile.employmentStatus] ??
                          profile.employmentStatus
                    ),
                    ('Atasan', profile.supervisorName ?? '-'),
                    ('Alamat', profile.address ?? '-'),
                  ],
                ),
                _InfoCard(
                  title: 'Rekening Gaji',
                  rows: [
                    ('Bank', profile.bankName ?? '-'),
                    ('No. Rekening', profile.maskedBankAccount),
                    ('NPWP', profile.npwp ?? '-'),
                    ('BPJS Kesehatan', profile.bpjsKesehatan ?? '-'),
                    ('BPJS Ketenagakerjaan', profile.bpjsTk ?? '-'),
                  ],
                ),
              ],
              _MenuCard(
                canSeeTeam: auth.canSeeTeam,
                onLogout: () => _confirmLogout(context, ref),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Logistax Mobile v1.0.0',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final EmployeeProfile profile;

  String get _initials {
    final parts = profile.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photo = profile.photoUrl;
    final subtitle = [profile.positionName, profile.departmentName]
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.teal],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white,
            backgroundImage: (photo != null && photo.isNotEmpty)
                ? CachedNetworkImageProvider(photo)
                : null,
            child: (photo != null && photo.isNotEmpty)
                ? null
                : Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.fullName.isEmpty ? '-' : profile.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          StatusBadge(
            label: AppStrings.employmentStatusLabel[profile.employmentStatus] ??
                profile.employmentStatus,
            color: Colors.white,
            fontSize: 12,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        row.$1,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2.isEmpty ? '-' : row.$2,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.canSeeTeam, required this.onLogout});

  final bool canSeeTeam;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          _MenuTile(
            icon: Icons.badge_rounded,
            label: 'Edit Profil',
            onTap: () => context.push('/profil/edit'),
          ),
          _MenuTile(
            icon: Icons.lock_rounded,
            label: 'Ubah Password',
            onTap: () => context.push('/profil/password'),
          ),
          _MenuTile(
            icon: Icons.tune_rounded,
            label: 'Pengaturan Notifikasi',
            onTap: () => context.push('/profil/notifikasi'),
          ),
          _MenuTile(
            icon: Icons.receipt_long_rounded,
            label: 'Slip Gaji',
            onTap: () => context.push('/slip'),
          ),
          _MenuTile(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Pinjaman',
            onTap: () => context.push('/pinjaman'),
          ),
          _MenuTile(
            icon: Icons.insights_rounded,
            label: 'KPI Saya',
            onTap: () => context.push('/kpi'),
          ),
          if (canSeeTeam)
            _MenuTile(
              icon: Icons.groups_rounded,
              label: 'Tim Saya',
              onTap: () => context.go('/spv/tim'),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'Keluar',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.teal),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
