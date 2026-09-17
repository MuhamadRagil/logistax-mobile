import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
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

/// Langkah 2: alasan cuti + lampiran dokumen (opsional).
class LeaveFormStep2Page extends ConsumerStatefulWidget {
  const LeaveFormStep2Page({super.key});

  @override
  ConsumerState<LeaveFormStep2Page> createState() => _LeaveFormStep2PageState();
}

class _LeaveFormStep2PageState extends ConsumerState<LeaveFormStep2Page> {
  late final TextEditingController _reasonCtrl;
  String? _documentName;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(leaveDraftProvider);
    _reasonCtrl = TextEditingController(text: draft.reason);
    _documentName = draft.documentName;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _documentName = result.files.first.name);
    }
  }

  void _next() {
    final reason = _reasonCtrl.text.trim();
    ref.read(leaveDraftProvider.notifier).state =
        ref.read(leaveDraftProvider).copyWith(
              reason: reason,
              documentName: _documentName,
              clearDocument: _documentName == null,
            );
    context.push('/cuti/konfirmasi');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canProceed = _reasonCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Cuti')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _StepIndicator(2),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alasan Cuti',
              hintText: 'Jelaskan alasan pengajuan cuti Anda',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          if (_documentName == null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickDocument,
                icon: const Icon(Icons.attach_file),
                label: const Text('Lampirkan Dokumen (opsional)'),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.insert_drive_file_outlined, size: 18),
                label: Text(_documentName!),
                onDeleted: () => setState(() => _documentName = null),
                deleteIcon: const Icon(Icons.close, size: 18),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Catatan: upload dokumen ke server belum tersedia — dokumen hanya '
            'sebagai penanda di perangkat.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Kembali'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Lanjut ke Konfirmasi',
                  onPressed: canProceed ? _next : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
