import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/currency_util.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/payslip_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/logistax_logo.dart';
import '../../providers/payroll_provider.dart';

/// Warna dokumen slip gaji — SELALU hitam/abu di atas kertas putih,
/// tidak mengikuti tema (dokumen resmi).
const _docBlack = Color(0xFF111111);
const _docGray = Color(0xFF6B7280);
const _docLine = Color(0x22000000);

/// Detail slip gaji: dokumen "kertas" putih + aksi unduh/bagikan PDF.
class PayslipDetailPage extends ConsumerStatefulWidget {
  final String slipId;
  final Payslip? initial;

  const PayslipDetailPage({super.key, required this.slipId, this.initial});

  @override
  ConsumerState<PayslipDetailPage> createState() => _PayslipDetailPageState();
}

class _PayslipDetailPageState extends ConsumerState<PayslipDetailPage> {
  bool _downloading = false;

  Future<void> _downloadPdf(Payslip slip) async {
    setState(() => _downloading = true);
    try {
      final month = slip.periodMonth.toString().padLeft(2, '0');
      final path = await ref.read(payrollRepositoryProvider).downloadPdf(
            slip.id,
            'slip-gaji-${slip.periodYear}-$month.pdf',
          );
      if (!mounted) return;
      await OpenFilex.open(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF dilindungi password: ${slip.pdfPasswordHint}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiException.fromDio(e).message),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(slipDetailProvider(widget.slipId));
    // Tampilkan data dari halaman sebelumnya selagi detail dimuat.
    final slip = async.valueOrNull ?? widget.initial;

    final Widget body;
    if (slip != null) {
      body = _body(slip);
    } else if (async.hasError) {
      body = ErrorState(
        error: async.error!,
        onRetry: () => ref.invalidate(slipDetailProvider(widget.slipId)),
      );
    } else {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingShimmer(count: 3, height: 160),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Slip Gaji')),
      body: body,
    );
  }

  Widget _body(Payslip slip) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _PayslipDocument(slip: slip),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'Unduh PDF',
            icon: Icons.download_rounded,
            loading: _downloading,
            onPressed: () => _downloadPdf(slip),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/slip/bagikan', extra: slip),
            icon: const Icon(Icons.share_rounded, size: 20),
            label: const Text('Bagikan'),
          ),
        ),
      ],
    );
  }
}

/// Dokumen slip gaji — kartu putih dengan teks hitam eksplisit.
class _PayslipDocument extends StatelessWidget {
  final Payslip slip;

  const _PayslipDocument({required this.slip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 14),
          _banner(),
          const SizedBox(height: 14),
          _infoGrid(),
          const SizedBox(height: 12),
          _attendanceRow(),
          const SizedBox(height: 14),
          _columns(),
          const SizedBox(height: 12),
          _totals(),
          const SizedBox(height: 12),
          _takeHomePay(),
          if (slip.terbilang.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Terbilang: ${slip.terbilang}',
              style: const TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: _docGray,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        LogistaxLogo(fontSize: 18),
        Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'PT Logistax Indonesia',
              style: TextStyle(fontSize: 10, color: _docGray, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 2),
            Text('Slip Gaji Karyawan', style: TextStyle(fontSize: 10, color: _docGray)),
          ],
        ),
      ],
    );
  }

  Widget _banner() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.teal,
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: const Text(
            'SLIP GAJI',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(width: double.infinity, height: 2, color: AppColors.navy),
      ],
    );
  }

  Widget _infoGrid() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _info('Nama', slip.employeeName ?? '-')),
            Expanded(child: _info('No. ID', slip.nik ?? '-')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _info('Bulan', monthLabel(slip.periodMonth, slip.periodYear))),
            Expanded(child: _info('Jabatan', slip.positionName ?? '-')),
          ],
        ),
      ],
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _docGray)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: _docBlack, fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _attendanceRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _docLine),
          bottom: BorderSide(color: _docLine),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _count('Hari Kerja', slip.workingDays)),
          Expanded(child: _count('Hadir', slip.presentDays)),
          Expanded(child: _count('Terlambat', slip.lateDays)),
          Expanded(child: _count('Absen', slip.absentDays)),
        ],
      ),
    );
  }

  Widget _count(String label, int value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _docGray),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: const TextStyle(fontSize: 13, color: _docBlack, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _columns() {
    final penerimaan = <_DocRow>[
      // Gaji pokok selalu tampil, walau 0.
      _DocRow('Gaji Pokok', slip.gajiPokok),
      _DocRow('Tunjangan', slip.tunjangan),
      _DocRow('Lembur', slip.lembur),
      _DocRow('Transport', slip.transport),
      _DocRow('Bonus/THR', slip.bonusThr),
    ].where((r) => r.label == 'Gaji Pokok' || r.value != 0).toList();

    final potongan = <_DocRow>[
      _DocRow('Pinjaman', slip.pinjamanKaryawan),
      _DocRow('Pot. Absen', slip.potonganAbsen),
      _DocRow('PPh 21', slip.pph21Karyawan),
      _DocRow('BPJS', slip.bpjsKaryawan),
    ].where((r) => r.value != 0).toList();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _section('PENERIMAAN', penerimaan)),
          const VerticalDivider(width: 21, thickness: 1, color: _docLine),
          Expanded(child: _section('POTONGAN', potongan)),
        ],
      ),
    );
  }

  Widget _section(String title, List<_DocRow> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.navy, width: 1)),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.navy,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          const Text('-', style: TextStyle(fontSize: 11, color: _docGray))
        else
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      r.label,
                      style: const TextStyle(fontSize: 11, color: _docBlack),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 4,
                    child: Text(
                      formatRupiah(r.value),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _docBlack,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _totals() {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _total('Total Penerimaan', slip.totalPenerimaan)),
          const SizedBox(width: 12),
          Expanded(child: _total('Total Potongan', slip.totalPotongan)),
        ],
      ),
    );
  }

  Widget _total(String label, num value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: _docBlack, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          formatRupiah(value),
          style: const TextStyle(fontSize: 12, color: _docBlack, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _takeHomePay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'TAKE HOME PAY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupiah(slip.takeHomePay),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Hormat kami,', style: TextStyle(fontSize: 11, color: _docBlack)),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.only(top: 3),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black54)),
            ),
            child: const Text(
              'Direktur',
              style: TextStyle(fontSize: 11, color: _docBlack, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris komponen gaji (label + nominal).
class _DocRow {
  final String label;
  final num value;

  const _DocRow(this.label, this.value);
}
