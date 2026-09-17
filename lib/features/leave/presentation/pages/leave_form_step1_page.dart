import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/models/leave_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../providers/leave_provider.dart';

/// Indikator langkah form cuti (3 lingkaran + garis). Disalin ke tiap halaman form.
class _StepIndicator extends StatelessWidget {
  final int current; // 1..3
  const _StepIndicator(this.current);

  static const _labels = ['Detail', 'Alasan', 'Konfirmasi'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (var step = 1; step <= 3; step++) {
      final active = step <= current;
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor:
                  active ? AppColors.teal : theme.colorScheme.surfaceContainerHighest,
              child: active && step < current
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        color: active ? Colors.white : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              _labels[step - 1],
              style: theme.textTheme.labelSmall?.copyWith(
                color: active ? AppColors.teal : theme.colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
      if (step < 3) {
        children.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: step < current
                  ? AppColors.teal
                  : theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// Langkah 1: pilih jenis cuti & rentang tanggal.
class LeaveFormStep1Page extends ConsumerStatefulWidget {
  const LeaveFormStep1Page({super.key});

  @override
  ConsumerState<LeaveFormStep1Page> createState() => _LeaveFormStep1PageState();
}

class _LeaveFormStep1PageState extends ConsumerState<LeaveFormStep1Page> {
  String? _leaveTypeId;
  String? _leaveTypeName;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(leaveDraftProvider);
    _leaveTypeId = draft.leaveTypeId;
    _leaveTypeName = draft.leaveTypeName;
    _startDate = draft.startDate;
    _endDate = draft.endDate;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _next() {
    ref.read(leaveDraftProvider.notifier).update(
          (d) => d.copyWith(
            leaveTypeId: _leaveTypeId,
            leaveTypeName: _leaveTypeName,
            startDate: _startDate,
            endDate: _endDate,
          ),
        );
    context.push('/cuti/ajukan/2');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typesAsync = ref.watch(leaveTypesProvider);
    final balances =
        ref.watch(myBalancesProvider(DateTime.now().year)).valueOrNull ?? const [];

    final days = (_startDate != null && _endDate != null)
        ? countWorkingDays(_startDate!, _endDate!)
        : 0;

    LeaveBalance? matchBalance;
    if (_leaveTypeId != null) {
      final m = balances.where((b) => b.leaveTypeId == _leaveTypeId);
      matchBalance = m.isEmpty ? null : m.first;
    }
    final showWarning = matchBalance != null && days > 0 && matchBalance.remaining < days;

    final canProceed = _leaveTypeId != null && _startDate != null && _endDate != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Cuti')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _StepIndicator(1),
          const SizedBox(height: 16),
          Text('Jenis Cuti', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          typesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text(
              'Gagal memuat jenis cuti',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            data: (rawTypes) {
              // Sakit & Izin dilaporkan lewat tab Absensi, bukan lewat form ini.
              final types = rawTypes.where((t) {
                final n = t.name.toLowerCase();
                return !n.contains('sakit') && !n.contains('izin');
              }).toList();
              return DropdownButtonFormField<String>(
                initialValue: _leaveTypeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Pilih jenis cuti',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: types
                    .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _leaveTypeId = val;
                    _leaveTypeName = val == null
                        ? null
                        : types.firstWhere((t) => t.id == val).name;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Untuk sakit atau izin, gunakan fitur di tab Absensi',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Text('Rentang Tanggal', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Tanggal Mulai',
                  value: _startDate == null ? null : formatDateShort(_startDate),
                  onTap: _pickRange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Tanggal Selesai',
                  value: _endDate == null ? null : formatDateShort(_endDate),
                  onTap: _pickRange,
                ),
              ),
            ],
          ),
          if (days > 0) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.tealLight,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: AppColors.teal),
                    const SizedBox(width: 12),
                    Text(
                      'Total $days hari kerja',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (showWarning) ...[
            const SizedBox(height: 12),
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
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Saldo tidak mencukupi (sisa ${matchBalance.remaining} hari) '
                      '— pengajuan tetap bisa dikirim',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Lanjut',
              onPressed: canProceed ? _next : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value ?? 'Pilih tanggal',
          style: value == null
              ? theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              : theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
