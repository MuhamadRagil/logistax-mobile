import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/attendance_model.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../providers/attendance_provider.dart';

/// Riwayat absensi bulanan dalam bentuk kalender bertanda warna.
class AttendanceHistoryPage extends ConsumerStatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  ConsumerState<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends ConsumerState<AttendanceHistoryPage> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final params = (year: _focusedMonth.year, month: _focusedMonth.month);
    final async = ref.watch(myMonthlyProvider(params));

    final employee = async.valueOrNull;
    final records = employee?.records ?? const <AttendanceRecord>[];
    final byDate = <String, AttendanceRecord>{
      for (final r in records) _recordKey(r): r,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Absensi'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(myMonthlyProvider(params)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          TableCalendar<AttendanceRecord>(
            firstDay: DateTime(now.year - 2, now.month, 1),
            lastDay: DateTime(now.year, now.month + 2, 0),
            focusedDay: _focusedMonth,
            calendarFormat: CalendarFormat.month,
            availableGestures: AvailableGestures.horizontalSwipe,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              final r = byDate[toApiDate(day)];
              return r == null ? const <AttendanceRecord>[] : <AttendanceRecord>[r];
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold),
              selectedDecoration: BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders<AttendanceRecord>(
              headerTitleBuilder: (context, day) => Center(
                child: Text(
                  monthLabel(day.month, day.year),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  height: 7,
                  width: 7,
                  decoration: BoxDecoration(
                    color: AppColors.attendanceStatus(events.first.status),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            onPageChanged: (focusedDay) {
              setState(() => _focusedMonth = focusedDay);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedMonth = focusedDay;
              });
              final record = byDate[toApiDate(selectedDay)];
              if (record != null) _showDetail(context, selectedDay, record);
            },
          ),
          const Divider(height: 24),

          if (async.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (async.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Gagal memuat rekap bulan ini.')),
                  TextButton(
                    onPressed: () => ref.invalidate(myMonthlyProvider(params)),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SummaryChips(summary: employee?.summary),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _Legend(),
            ),
          ],
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, DateTime day, AttendanceRecord record) {
    final color = AppColors.attendanceStatus(record.status);
    final label = AppStrings.attendanceStatusLabel[record.status] ?? record.status;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDateFull(day),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              StatusBadge(label: label, color: color, fontSize: 13),
              const SizedBox(height: 18),
              _DetailRow(
                icon: Icons.login_rounded,
                label: 'Jam Masuk',
                value: record.checkInTime != null ? formatTimeWib(record.checkInTime) : '-',
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.logout_rounded,
                label: 'Jam Keluar',
                value: record.checkOutTime != null ? formatTimeWib(record.checkOutTime) : '-',
              ),
              if (record.lateMinutes > 0) ...[
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.timer_off_rounded,
                  label: 'Keterlambatan',
                  value: '${record.lateMinutes} menit',
                ),
              ],
              if (record.notes != null && record.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.sticky_note_2_rounded,
                  label: 'Catatan',
                  value: record.notes!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kunci tanggal record ("2026-07-20"); backend bisa mengirim ISO lengkap.
String _recordKey(AttendanceRecord record) {
  final date = record.date;
  return date.length >= 10 ? date.substring(0, 10) : date;
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({this.summary});

  final AttendanceSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary ?? const AttendanceSummary();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('${s.present} Hadir', AppColors.present),
        _chip('${s.late} Terlambat', AppColors.late),
        _chip('${s.absent} Absen', AppColors.absent),
        _chip('${s.cuti} Cuti', AppColors.leave),
      ],
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  static const _items = <String>['present', 'late', 'absent', 'cuti', 'sick', 'wfh', 'holiday'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keterangan Warna',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final status in _items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 9,
                    width: 9,
                    decoration: BoxDecoration(
                      color: AppColors.attendanceStatus(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.attendanceStatusLabel[status] ?? status,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
