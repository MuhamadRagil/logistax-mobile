import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../models/intern_models.dart';
import '../../providers/intern_providers.dart';
import '../../providers/intern_session.dart';

/// Status & unduhan sertifikat magang. PDF dilindungi password = NIM;
/// info ini ditampilkan jelas SEBELUM tombol unduh ditekan.
class InternCertificatePage extends ConsumerStatefulWidget {
  const InternCertificatePage({super.key});

  @override
  ConsumerState<InternCertificatePage> createState() => _InternCertificatePageState();
}

class _InternCertificatePageState extends ConsumerState<InternCertificatePage> {
  bool _downloading = false;

  Future<void> _download(String nim) async {
    setState(() => _downloading = true);
    try {
      final path = await ref.read(internRepositoryProvider).downloadCertificate(nim);
      final result = await OpenFilex.open(path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sertifikat tersimpan, tapi tidak bisa dibuka otomatis '
              '(${result.message}). Pasang aplikasi pembaca PDF.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDio(e).message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(internCertificateProvider);
    final nim = ref.watch(internSessionProvider).profile?.nim ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Sertifikat')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(internCertificateProvider);
          await ref.read(internCertificateProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 80),
              ErrorState(error: e, onRetry: () => ref.invalidate(internCertificateProvider)),
            ],
          ),
          data: (cert) => cert == null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Sertifikat belum tersedia',
                      description:
                          'Sertifikat diterbitkan setelah masa magang selesai dan evaluasi Anda lengkap.',
                    ),
                  ],
                )
              : _CertificateView(
                  cert: cert,
                  nim: nim,
                  downloading: _downloading,
                  onDownload: () => _download(nim),
                ),
        ),
      ),
    );
  }
}

class _CertificateView extends StatelessWidget {
  const _CertificateView({
    required this.cert,
    required this.nim,
    required this.downloading,
    required this.onDownload,
  });

  final InternCertificate cert;
  final String nim;
  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 56, color: AppColors.teal),
                const SizedBox(height: 10),
                Text(
                  'Sertifikat Tersedia',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _row(theme, 'Nomor', cert.certificateNumber ?? '-'),
                _row(theme, 'Tanggal Terbit', formatDateLong(cert.issuedDate)),
                _row(theme, 'Kota', cert.issuedCity ?? '-'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    children: [
                      const TextSpan(
                        text: 'PDF sertifikat dilindungi password. ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: 'Setelah diunduh, aplikasi PDF akan meminta password saat file dibuka. '
                            'Password-nya adalah NIM Anda',
                      ),
                      TextSpan(
                        text: nim.isEmpty ? '.' : ': $nim',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Unduh & Buka PDF',
          icon: Icons.download_rounded,
          loading: downloading,
          onPressed: onDownload,
        ),
      ],
    );
  }

  Widget _row(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
