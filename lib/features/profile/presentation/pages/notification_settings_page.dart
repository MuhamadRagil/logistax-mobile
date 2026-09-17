import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan preferensi notifikasi lokal.
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  static const _prefKeys = <String, String>{
    'leave': 'notif_leave',
    'payroll': 'notif_payroll',
    'kpi': 'notif_kpi',
    'attendance': 'notif_attendance',
  };

  final Map<String, bool> _values = {
    'leave': true,
    'payroll': true,
    'kpi': true,
    'attendance': true,
  };

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final entry in _prefKeys.entries) {
        _values[entry.key] = prefs.getBool(entry.value) ?? true;
      }
      _loaded = true;
    });
  }

  Future<void> _setPref(String name, bool value) async {
    setState(() => _values[name] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeys[name]!, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _SectionTitle('Notifikasi'),
          SwitchListTile(
            value: _values['leave']!,
            onChanged: _loaded ? (v) => _setPref('leave', v) : null,
            title: const Text('Pengajuan Cuti'),
            subtitle: const Text('Status persetujuan & pengajuan baru'),
            secondary: const Icon(Icons.event_available_rounded),
          ),
          SwitchListTile(
            value: _values['payroll']!,
            onChanged: _loaded ? (v) => _setPref('payroll', v) : null,
            title: const Text('Slip Gaji'),
            subtitle: const Text('Slip gaji bulanan siap dilihat'),
            secondary: const Icon(Icons.receipt_long_rounded),
          ),
          SwitchListTile(
            value: _values['kpi']!,
            onChanged: _loaded ? (v) => _setPref('kpi', v) : null,
            title: const Text('KPI'),
            subtitle: const Text('Nilai KPI bulanan dipublikasikan'),
            secondary: const Icon(Icons.insights_rounded),
          ),
          SwitchListTile(
            value: _values['attendance']!,
            onChanged: _loaded ? (v) => _setPref('attendance', v) : null,
            title: const Text('Pengingat Absensi'),
            subtitle: const Text('Pengingat check-in & check-out'),
            secondary: const Icon(Icons.alarm_rounded),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Push notification akan aktif setelah Firebase dikonfigurasi. '
              'Notifikasi dalam aplikasi tetap berjalan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
