import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/currency_util.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/payslip_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../providers/payroll_provider.dart';

/// Bagikan slip gaji sebagai PDF (terkunci password) atau simpan ke perangkat.
class PayslipSharePage extends ConsumerStatefulWidget {
  final Payslip slip;

  const PayslipSharePage({super.key, required this.slip});

  @override
  ConsumerState<PayslipSharePage> createState() => _PayslipSharePageState();
}

class _PayslipSharePageState extends ConsumerState<PayslipSharePage> {
  bool _sharing = false;
  bool _saving = false;

  String get _periode => monthLabel(widget.slip.periodMonth, widget.slip.periodYear);

  String get _filename {
    final month = widget.slip.periodMonth.toString().padLeft(2, '0');
    return 'slip-gaji-${widget.slip.periodYear}-$month.pdf';
  }

  Future<String> _download() =>
      ref.read(payrollRepositoryProvider).downloadPdf(widget.slip.id, _filename);

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ApiException.fromDio(e).message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final path = await _download();
      if (!mounted) return;
      await Share.shareXFiles([XFile(path)], text: 'Slip Gaji $_periode');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final path = await _download();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tersimpan di: $path'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
        ),
      );
      await OpenFilex.open(path);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slip = widget.slip;

    return Scaffold(
      appBar: AppBar(title: const Text('Bagikan Slip')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.tealLight,
                    child: Icon(Icons.receipt_long_rounded, color: AppColors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _periode,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Take Home Pay',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatRupiah(slip.takeHomePay),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PDF dilindungi password. Password = 6 digit terakhir No. ID Anda '
                    '(contoh: ${slip.pdfPasswordHint}).',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Bagikan via WhatsApp/Aplikasi Lain',
              icon: Icons.share_rounded,
              loading: _sharing,
              onPressed: _saving ? null : _share,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Simpan ke Perangkat',
              icon: Icons.save_alt_rounded,
              outlined: true,
              loading: _saving,
              onPressed: _sharing ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}
