import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../models/intern_models.dart';
import '../../providers/intern_providers.dart';
import '../../providers/intern_session.dart';

/// Absensi GPS intern. Berbeda dengan halaman absensi karyawan, radius kantor
/// divalidasi di SERVER — app hanya mengirim koordinat mentah lalu
/// menampilkan pesan dari backend (mis. "Lokasi Anda di luar radius kantor").
/// Penanganan izin lokasi mengikuti pola `AttendanceButtonPage` (disalin,
/// bukan di-share, agar halaman karyawan tidak tersentuh).
class InternAttendancePage extends ConsumerStatefulWidget {
  const InternAttendancePage({super.key});

  @override
  ConsumerState<InternAttendancePage> createState() => _InternAttendancePageState();
}

class _InternAttendancePageState extends ConsumerState<InternAttendancePage> {
  bool _submitting = false;
  String? _locationError;
  bool _canOpenSettings = false;

  /// Pastikan layanan lokasi hidup dan izin diberikan; simpan pesan error
  /// bila tidak, supaya UI bisa menawarkan buka pengaturan.
  Future<bool> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _setLocationError('Layanan lokasi mati. Aktifkan GPS lalu coba lagi.', settings: true);
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _setLocationError(
        'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
        settings: true,
      );
      return false;
    }
    if (permission == LocationPermission.denied) {
      _setLocationError('Izin lokasi diperlukan untuk absensi.');
      return false;
    }
    return true;
  }

  void _setLocationError(String message, {bool settings = false}) {
    if (!mounted) return;
    setState(() {
      _locationError = message;
      _canOpenSettings = settings;
    });
  }

  Future<void> _submit({required bool checkIn}) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _locationError = null;
      _canOpenSettings = false;
    });

    try {
      if (!await _ensureLocationAccess()) return;

      final Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        _setLocationError('Gagal mengambil lokasi. Pastikan GPS aktif dan coba di area terbuka.');
        return;
      }

      final repo = ref.read(internRepositoryProvider);
      final message = checkIn
          ? await repo.checkIn(pos.latitude, pos.longitude)
          : await repo.checkOut(pos.latitude, pos.longitude);

      ref.invalidate(internTodayProvider);
      ref.invalidate(internHistoryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.success),
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(internSessionProvider).profile;
    final today = ref.watch(internTodayProvider);
    final now = internServerToday();
    final history = ref.watch(internHistoryProvider((year: now.year, month: now.month)));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Absensi GPS')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(internTodayProvider);
          ref.invalidate(internHistoryProvider);
          await ref.read(internTodayProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              formatDateFull(DateTime.now()),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            today.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  ErrorState(error: e, onRetry: () => ref.invalidate(internTodayProvider)),
              data: (record) => _ActionArea(
                record: record,
                canAttend: profile?.canAttend ?? false,
                statusLabel: profile?.statusLabel ?? '-',
                submitting: _submitting,
                onCheckIn: () => _submit(checkIn: true),
                onCheckOut: () => _submit(checkIn: false),
              ),
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_locationError!, style: const TextStyle(color: AppColors.error)),
                    if (_canOpenSettings)
                      TextButton.icon(
                        onPressed: () async {
                          final off = !await Geolocator.isLocationServiceEnabled();
                          off
                              ? await Geolocator.openLocationSettings()
                              : await Geolocator.openAppSettings();
                        },
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: const Text('Buka Pengaturan'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Lokasi Anda dikirim ke server dan divalidasi terhadap radius kantor terdaftar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              'Riwayat Bulan Ini',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            history.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(internHistoryProvider),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Belum ada absensi bulan ini.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : Column(children: [for (final a in list) _HistoryTile(item: a)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.record,
    required this.canAttend,
    required this.statusLabel,
    required this.submitting,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final InternAttendance? record;
  final bool canAttend;
  final String statusLabel;
  final bool submitting;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    final r = record;

    Widget info(String text, Color color, IconData icon) => Card(
          child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        );

    if (!canAttend) {
      return info(
        'Absensi hanya untuk status magang aktif (status Anda: $statusLabel).',
        AppColors.warning,
        Icons.info_outline_rounded,
      );
    }
    if (r != null && r.isLeave) {
      return info(
        'Anda mengajukan ${r.statusLabel.toLowerCase()} untuk hari ini — tidak bisa check-in.',
        AppColors.leave,
        Icons.event_note_rounded,
      );
    }
    if (r != null && r.hasCheckedOut) {
      return info(
        'Absensi hari ini selesai (masuk ${formatTime(r.checkInTime)}, pulang ${formatTime(r.checkOutTime)}).',
        AppColors.success,
        Icons.check_circle_rounded,
      );
    }

    final isCheckIn = r == null || !r.hasCheckedIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isCheckIn)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Check-in pukul ${formatTime(r.checkInTime)} WIB',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600),
            ),
          ),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: submitting ? null : (isCheckIn ? onCheckIn : onCheckOut),
            icon: submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Icon(isCheckIn ? Icons.login_rounded : Icons.logout_rounded),
            label: Text(
              submitting ? 'Mengambil lokasi...' : (isCheckIn ? 'Check-in' : 'Check-out'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final InternAttendance item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      'hadir' => AppColors.success,
      'izin' || 'sakit' => AppColors.leave,
      'absen' => AppColors.error,
      _ => AppColors.holiday,
    };
    final detail = item.isLeave
        ? (internApprovalLabel[item.approvalStatus] ?? '-')
        : '${formatTime(item.checkInTime)} – ${formatTime(item.checkOutTime)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(formatDateFull(item.date)),
        subtitle: Text(detail),
        trailing: Text(
          item.statusLabel,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
