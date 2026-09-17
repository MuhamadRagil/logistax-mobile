import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/haversine_util.dart';
import '../../../../shared/models/attendance_model.dart';
import '../../../../shared/models/office_location_model.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/logistax_app_bar.dart';
import '../../providers/attendance_provider.dart';

/// Tujuan absensi — dipakai router lewat query `tujuan`.
enum AttendancePurpose { checkIn, checkOut }

/// Interval refresh posisi GPS saat halaman terbuka.
const _kGpsRefreshInterval = Duration(seconds: 3);

/// Titik absensi yang valid: lokasi yang di-assign, atau kantor global.
class _Site {
  const _Site(this.name, this.latitude, this.longitude, this.radiusMeters);

  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
}

class _Proximity {
  const _Proximity(this.site, this.distance);

  final _Site site;
  final double distance;

  bool get inside => distance <= site.radiusMeters;
}

/// Halaman absensi berbasis tombol + GPS (menggantikan pemindai QR).
///
/// Posisi GPS di-refresh tiap 3 detik dan dibandingkan dengan semua lokasi
/// yang di-assign ke karyawan (`GET /employees/:id/locations`). Tanpa
/// assignment, dipakai titik kantor dari `GET /settings/attendance`.
/// Server tetap memvalidasi ulang jarak saat request dikirim.
class AttendanceButtonPage extends ConsumerStatefulWidget {
  const AttendanceButtonPage({super.key, required this.purpose});

  final AttendancePurpose purpose;

  @override
  ConsumerState<AttendanceButtonPage> createState() => _AttendanceButtonPageState();
}

class _AttendanceButtonPageState extends ConsumerState<AttendanceButtonPage> {
  Timer? _gpsTimer;
  Position? _position;
  String? _gpsError;
  bool _gpsLoading = true;
  bool _fetching = false; // cegah tumpang tindih antar tick timer
  bool _submitting = false;

  bool get _isCheckIn => widget.purpose == AttendancePurpose.checkIn;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  // ── GPS ────────────────────────────────────────────────────────────────

  Future<void> _startTracking() async {
    _gpsTimer?.cancel();
    if (mounted) {
      setState(() {
        _gpsLoading = true;
        _gpsError = null;
      });
    }

    final ready = await _ensureLocationAccess();
    if (!mounted || !ready) return;

    await _refreshPosition();
    if (!mounted) return;
    _gpsTimer = Timer.periodic(_kGpsRefreshInterval, (_) => _refreshPosition());
  }

  /// Pastikan layanan lokasi hidup dan izin diberikan. Menyimpan pesan error
  /// bila tidak, supaya UI bisa menawarkan tombol coba lagi / buka pengaturan.
  Future<bool> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _setGpsError('Layanan lokasi mati. Aktifkan GPS lalu coba lagi.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _setGpsError('Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.');
      return false;
    }
    if (permission == LocationPermission.denied) {
      _setGpsError('Izin lokasi diperlukan untuk absensi.');
      return false;
    }
    return true;
  }

  Future<void> _refreshPosition() async {
    if (_fetching || !mounted) return;
    _fetching = true;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _kGpsRefreshInterval,
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = pos;
        _gpsLoading = false;
        _gpsError = null;
      });
    } catch (_) {
      // Timeout satu tick bukan kegagalan fatal selama posisi lama masih ada.
      if (!mounted) return;
      if (_position == null) {
        _setGpsError('Gagal mengambil lokasi. Pastikan GPS aktif lalu coba lagi.');
      }
    } finally {
      _fetching = false;
    }
  }

  void _setGpsError(String message) {
    _gpsTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _gpsLoading = false;
      _gpsError = message;
    });
  }

  // ── Lokasi ─────────────────────────────────────────────────────────────

  List<_Site> _sitesFor(AttendanceSettings settings, List<OfficeLocation> locations) {
    if (locations.isEmpty) {
      return [
        _Site('Kantor', settings.officeLatitude, settings.officeLongitude,
            settings.gpsRadiusMeters),
      ];
    }
    return [
      for (final loc in locations)
        _Site(loc.name, loc.latitude, loc.longitude, loc.radiusMeters),
    ];
  }

  /// Lokasi terdekat yang radiusnya mencakup posisi saya; bila tidak ada,
  /// lokasi terdekat secara absolut. Null bila posisi belum tersedia.
  _Proximity? _resolve(List<_Site> sites) {
    final pos = _position;
    if (pos == null || sites.isEmpty) return null;
    final all = [
      for (final site in sites)
        _Proximity(
          site,
          haversineMeters(pos.latitude, pos.longitude, site.latitude, site.longitude),
        ),
    ]..sort((a, b) => a.distance.compareTo(b.distance));
    return all.firstWhere((p) => p.inside, orElse: () => all.first);
  }

  // ── Submit absensi ─────────────────────────────────────────────────────

  Future<void> _submit() async {
    final position = _position;
    if (position == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final result = _isCheckIn
          ? await repo.checkIn(position.latitude, position.longitude)
          : await repo.checkOut(position.latitude, position.longitude);

      if (!mounted) return;
      _gpsTimer?.cancel();
      context.pushReplacement('/absensi/sukses', extra: {
        'type': _isCheckIn ? 'checkin' : 'checkout',
        'record': result,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiException.fromDio(e).message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(attendanceSettingsProvider);
    final locationsAsync = ref.watch(myLocationsProvider);

    return Scaffold(
      appBar: LogistaxAppBar(title: _isCheckIn ? 'Absen Masuk' : 'Absen Pulang'),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () {
            ref.invalidate(attendanceSettingsProvider);
            ref.invalidate(myLocationsProvider);
          },
        ),
        data: (settings) => locationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _buildBody(settings, const []),
          data: (locations) => _buildBody(settings, locations),
        ),
      ),
    );
  }

  Widget _buildBody(AttendanceSettings settings, List<OfficeLocation> locations) {
    final multiLocation = locations.isNotEmpty;
    final sites = _sitesFor(settings, locations);
    final proximity = _resolve(sites);
    final inRadius = proximity?.inside ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _DistanceDial(
                      proximity: proximity,
                      loading: _gpsLoading,
                      hasError: _gpsError != null,
                    ),
                    if (proximity != null && _gpsError == null) ...[
                      const SizedBox(height: 14),
                      Text(
                        '📍 ${proximity.site.name}: ${_formatMeters(proximity.distance)}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _statusText(context, proximity, multiLocation),
                    const SizedBox(height: 20),
                    _InfoCard(
                      settings: settings,
                      position: _position,
                      radiusMeters: (proximity?.site ?? sites.first).radiusMeters,
                      locationCount: multiLocation ? locations.length : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _actionButton(inRadius),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _submitting ? null : _startTracking,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Perbarui lokasi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusText(BuildContext context, _Proximity? proximity, bool multiLocation) {
    final theme = Theme.of(context);

    late final String title;
    late final String subtitle;
    late final Color color;

    if (_gpsError != null) {
      title = 'Lokasi tidak tersedia';
      subtitle = _gpsError!;
      color = AppColors.error;
    } else if (proximity == null) {
      title = 'Mencari lokasi Anda...';
      subtitle = 'Pastikan GPS aktif dan Anda berada di area terbuka.';
      color = theme.colorScheme.onSurfaceVariant;
    } else if (proximity.inside) {
      title = '✅ ${proximity.site.name} (${_formatMeters(proximity.distance)})';
      subtitle = 'Tekan tombol di bawah untuk mencatat absensi.';
      color = AppColors.teal;
    } else {
      final nearest =
          'Lokasi terdekat: ${proximity.site.name} (${_formatMeters(proximity.distance)})';
      title = '❌ Di luar lokasi kantor';
      subtitle = multiLocation ? 'Di luar semua lokasi yang diizinkan.\n$nearest' : nearest;
      color = AppColors.error;
    }

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _actionButton(bool inRadius) {
    final label = _isCheckIn ? 'Absen Masuk' : 'Absen Pulang';
    final enabled = inRadius && !_submitting && _gpsError == null;

    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: enabled ? _submit : null,
        icon: _submitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Icon(_isCheckIn ? Icons.login_rounded : Icons.logout_rounded),
        label: Text(_submitting ? 'Memproses...' : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Lingkaran besar berisi jarak ke lokasi — teal bila di dalam radius.
class _DistanceDial extends StatelessWidget {
  const _DistanceDial({
    required this.proximity,
    required this.loading,
    required this.hasError,
  });

  final _Proximity? proximity;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = proximity;
    final inRadius = p?.inside ?? false;
    final color = hasError
        ? AppColors.error
        : p == null
            ? AppColors.holiday
            : (inRadius ? AppColors.teal : AppColors.warning);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 200,
      width: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 3),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasError
                    ? Icons.location_off_rounded
                    : inRadius
                        ? Icons.where_to_vote_rounded
                        : Icons.my_location_rounded,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 10),
              if (loading && p == null)
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Text(
                  p == null ? '--' : _formatMeters(p.distance),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                p == null ? 'dari lokasi' : 'dari ${p.site.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail radius yang diizinkan dan koordinat perangkat saat ini.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.settings,
    required this.position,
    required this.radiusMeters,
    required this.locationCount,
  });

  final AttendanceSettings settings;
  final Position? position;
  final int radiusMeters;

  /// Null = mode kantor tunggal (tanpa assignment lokasi).
  final int? locationCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (locationCount != null) ...[
              _row(theme, Icons.place_rounded, 'Lokasi diizinkan', '$locationCount lokasi'),
              const SizedBox(height: 10),
            ],
            _row(theme, Icons.adjust_rounded, 'Radius diizinkan', '$radiusMeters meter'),
            const SizedBox(height: 10),
            _row(theme, Icons.schedule_rounded, 'Jam masuk', settings.workStartTime),
            const SizedBox(height: 10),
            _row(
              theme,
              Icons.gps_fixed_rounded,
              'Koordinat Anda',
              position == null
                  ? '-'
                  : '${position!.latitude.toStringAsFixed(5)}, '
                      '${position!.longitude.toStringAsFixed(5)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// "85 meter" / "1.2 km" — angka bulat supaya mudah dibaca sekilas.
String _formatMeters(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} meter';
}
