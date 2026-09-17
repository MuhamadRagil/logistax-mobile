import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/attendance_model.dart';
import '../../../../shared/models/leave_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/logistax_app_bar.dart';
import '../../../leave/providers/leave_provider.dart';
import '../../providers/attendance_provider.dart';

/// Jenis laporan cepat dari tab Absensi (bukan alur form cuti biasa).
enum _QuickReportKind { sick, izin }

extension on _QuickReportKind {
  String get label => this == _QuickReportKind.sick ? 'Sakit' : 'Izin';
  String get keyword => this == _QuickReportKind.sick ? 'sakit' : 'izin';
  IconData get icon =>
      this == _QuickReportKind.sick ? LucideIcons.thermometer : LucideIcons.calendarOff;
  Color get accentColor =>
      this == _QuickReportKind.sick ? const Color(0xFFEA580C) : const Color(0xFF2563EB);
}

/// Cari pengajuan cuti (pending/approved) bertipe Sakit/Izin yang mencakup
/// hari ini — dipakai untuk soft-block tombol absen di sisi klien selagi
/// menunggu HRD/SPV menyetujui (status absensi baru berubah setelah approve).
LeaveRequest? _todaysQuickReport(List<LeaveRequest>? requests) {
  if (requests == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  for (final r in requests) {
    if (r.status != 'pending' && r.status != 'approved') continue;
    final name = (r.leaveTypeName ?? '').toLowerCase();
    if (!name.contains('sakit') && !name.contains('izin')) continue;
    final start = DateTime.tryParse(r.startDate);
    final end = DateTime.tryParse(r.endDate);
    if (start == null || end == null) continue;
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    if (!today.isBefore(s) && !today.isAfter(e)) return r;
  }
  return null;
}

/// Halaman status absensi harian — titik masuk tombol absensi GPS masuk/pulang,
/// plus jalan pintas lapor Sakit/Izin hari ini tanpa lewat form cuti biasa.
class AttendanceStatusPage extends ConsumerWidget {
  const AttendanceStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTodayProvider);
    final todaysReport = _todaysQuickReport(ref.watch(myLeaveRequestsProvider).valueOrNull);
    final now = DateTime.now();

    return Scaffold(
      appBar: const LogistaxAppBar(title: 'Absensi'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTodayProvider);
          ref.invalidate(myLeaveRequestsProvider);
          await ref.read(myTodayProvider.future);
        },
        child: async.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: const [LoadingShimmer(count: 2, height: 170)],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: ErrorState(error: e, onRetry: () => ref.invalidate(myTodayProvider)),
              ),
            ],
          ),
          data: (record) => _Content(record: record, now: now, todaysReport: todaysReport),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.record, required this.now, required this.todaysReport});

  final AttendanceRecord? record;
  final DateTime now;
  final LeaveRequest? todaysReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = record?.status;
    final color = record == null ? AppColors.holiday : AppColors.attendanceStatus(status);
    final label = record == null
        ? 'Belum Absen'
        : (AppStrings.attendanceStatusLabel[status] ?? status ?? '-');

    // Belum absen tapi sudah lapor sakit/izin hari ini → sembunyikan tombol
    // absen & jalan pintas lapor, tampilkan status laporannya saja.
    final showQuickReportBanner = record == null && todaysReport != null;
    final showQuickReportShortcuts = record == null && todaysReport == null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header tanggal
          Text(
            formatDateFull(now),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          // Kartu status besar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon(record == null ? null : status), size: 52, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (record != null && status == 'late' && record!.lateMinutes > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${record!.lateMinutes} menit',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.login_rounded,
                  label: 'Jam Masuk',
                  value: record?.checkInTime != null ? formatTimeWib(record!.checkInTime) : '-',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.logout_rounded,
                  label: 'Jam Keluar',
                  value: record?.checkOutTime != null ? formatTimeWib(record!.checkOutTime) : '-',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.timelapse_rounded,
                  label: 'Durasi Kerja',
                  value: _durationText(record),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (showQuickReportBanner) ...[
            _QuickReportBanner(report: todaysReport!),
            const SizedBox(height: 12),
          ] else
            _primaryButton(context),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () => context.push('/absensi/riwayat'),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Lihat Riwayat'),
          ),

          if (showQuickReportShortcuts) ...[
            const SizedBox(height: 28),
            Text(
              'Tidak Masuk Hari Ini?',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickReportCard(
                    kind: _QuickReportKind.sick,
                    subtitle: 'Lapor sakit hari ini',
                    bgColor: const Color(0xFFFFF7ED),
                    onTap: () => _openReportSheet(context, ref, _QuickReportKind.sick),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickReportCard(
                    kind: _QuickReportKind.izin,
                    subtitle: 'Lapor izin hari ini',
                    bgColor: const Color(0xFFEFF6FF),
                    onTap: () => _openReportSheet(context, ref, _QuickReportKind.izin),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openReportSheet(BuildContext context, WidgetRef ref, _QuickReportKind kind) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QuickReportSheet(kind: kind),
    );
  }

  Widget _primaryButton(BuildContext context) {
    if (record == null) {
      return AppButton(
        label: 'Absen Masuk',
        icon: Icons.login_rounded,
        onPressed: () => context.push('/absensi/scan?tujuan=checkin'),
      );
    }
    if (record!.hasCheckedIn && !record!.hasCheckedOut) {
      return AppButton(
        label: 'Absen Pulang',
        icon: Icons.logout_rounded,
        color: AppColors.warning,
        onPressed: () => context.push('/absensi/scan?tujuan=checkout'),
      );
    }
    return const AppButton(
      label: 'Absensi Selesai',
      icon: Icons.check_circle_rounded,
      onPressed: null,
    );
  }
}

/// Kartu status saat sudah lapor sakit/izin hari ini — menggantikan tombol absen.
class _QuickReportBanner extends StatelessWidget {
  const _QuickReportBanner({required this.report});

  final LeaveRequest report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSick = (report.leaveTypeName ?? '').toLowerCase().contains('sakit');
    final kind = isSick ? _QuickReportKind.sick : _QuickReportKind.izin;
    final color = kind.accentColor;
    final pending = report.status == 'pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(kind.icon, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anda melapor ${report.leaveTypeName ?? '-'} hari ini',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  pending ? 'Menunggu persetujuan HRD/SPV' : 'Disetujui',
                  style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol kartu "Sakit" / "Izin" di section "Tidak Masuk Hari Ini?".
class _QuickReportCard extends StatelessWidget {
  const _QuickReportCard({
    required this.kind,
    required this.subtitle,
    required this.bgColor,
    required this.onTap,
  });

  final _QuickReportKind kind;
  final String subtitle;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = kind.accentColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(kind.icon, size: 24, color: accent),
            const SizedBox(height: 8),
            Text(
              kind.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet lapor Sakit/Izin hari ini: alasan (wajib) + foto (opsional).
class _QuickReportSheet extends ConsumerStatefulWidget {
  const _QuickReportSheet({required this.kind});

  final _QuickReportKind kind;

  @override
  ConsumerState<_QuickReportSheet> createState() => _QuickReportSheetState();
}

class _QuickReportSheetState extends ConsumerState<_QuickReportSheet> {
  final _reasonController = TextEditingController();
  XFile? _photo;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (photo != null && mounted) setState(() => _photo = photo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto')),
      );
    }
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Alasan wajib diisi');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final repo = ref.read(leaveRepositoryProvider);
    try {
      final types = await ref.read(leaveTypesProvider.future);
      LeaveType? type;
      for (final t in types) {
        if (t.name.toLowerCase().contains(widget.kind.keyword)) {
          type = t;
          break;
        }
      }
      if (type == null) {
        throw ApiException('Jenis cuti ${widget.kind.label} belum tersedia. Hubungi HRD.');
      }

      String? documentUrl;
      String? photoNote;
      if (_photo != null) {
        documentUrl = await repo.uploadDocument(_photo!.path);
        if (documentUrl == null) photoNote = 'Foto tidak dapat diunggah saat ini';
      }

      final today = toApiDate(DateTime.now());
      await repo.submit(
        leaveTypeId: type.id,
        startDate: today,
        endDate: today,
        reason: reason,
        documentUrl: documentUrl,
      );

      ref.invalidate(myTodayProvider);
      ref.invalidate(myLeaveRequestsProvider);
      ref.invalidate(myBalancesProvider(DateTime.now().year));

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            photoNote == null
                ? 'Laporan ${widget.kind.keyword} berhasil dikirim'
                : 'Laporan ${widget.kind.keyword} berhasil dikirim — $photoNote',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ApiException.fromDio(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Lapor ${widget.kind.label} Hari Ini',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _reasonController,
                label: 'Alasan',
                hint: 'Ceritakan alasan Anda ${widget.kind.keyword} hari ini',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text('Foto (opsional)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (_photo != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_photo!.path),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => setState(() => _photo = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Ambil Foto'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Pilih dari Galeri'),
                      ),
                    ),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: 'Kirim Laporan',
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

IconData _statusIcon(String? status) {
  switch (status) {
    case 'present':
      return Icons.check_circle_rounded;
    case 'late':
      return Icons.schedule_rounded;
    case 'cuti':
    case 'izin':
      return Icons.beach_access_rounded;
    case 'sick':
      return Icons.medical_services_rounded;
    case 'wfh':
      return Icons.home_work_rounded;
    case 'holiday':
      return Icons.celebration_rounded;
    default:
      return Icons.fingerprint_rounded;
  }
}

/// Durasi kerja: selisih check-out−check-in, atau durasi berjalan bila belum keluar.
String _durationText(AttendanceRecord? record) {
  if (record == null || record.checkInTime == null) return '-';
  final start = DateTime.tryParse(record.checkInTime!);
  if (start == null) return '-';
  final end = record.checkOutTime != null ? DateTime.tryParse(record.checkOutTime!) : DateTime.now();
  if (end == null) return '-';
  final d = end.difference(start);
  if (d.isNegative) return '-';
  return '${d.inHours}j ${d.inMinutes.remainder(60)}m';
}
