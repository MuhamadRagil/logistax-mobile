import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../models/intern_models.dart';
import '../../providers/intern_providers.dart';
import '../../providers/intern_session.dart';

/// Batas ukuran bukti dari validasi backend (`max:5120` KB).
const _kMaxProofBytes = 5 * 1024 * 1024;
const _kAllowedExt = ['jpg', 'jpeg', 'png', 'pdf'];

/// Form pengajuan izin/sakit intern → POST /attendance/leave-request.
/// Validasi di sini meniru aturan backend (bukti wajib untuk sakit, jpg/png/pdf,
/// maks 5 MB, catatan maks 1000 karakter) supaya user tidak menunggu 422.
class InternLeavePage extends ConsumerStatefulWidget {
  const InternLeavePage({super.key});

  @override
  ConsumerState<InternLeavePage> createState() => _InternLeavePageState();
}

class _InternLeavePageState extends ConsumerState<InternLeavePage> {
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String _status = 'izin';
  String? _proofPath;
  String? _proofName;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final profile = ref.read(internSessionProvider).profile;
    final start = DateTime.tryParse(profile?.startDate ?? '');
    final end = DateTime.tryParse(profile?.endDate ?? '');
    final now = DateTime.now();
    final first = start ?? DateTime(now.year - 1);
    final last = end ?? DateTime(now.year + 1);
    final initial = _date.isBefore(first) ? first : (_date.isAfter(last) ? last : _date);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (photo != null) await _setProof(photo.path, photo.name);
    } catch (_) {
      _snack('Gagal mengambil foto', AppColors.error);
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _kAllowedExt,
      );
      final file = (result != null && result.files.isNotEmpty) ? result.files.first : null;
      if (file?.path != null) await _setProof(file!.path!, file.name);
    } catch (_) {
      _snack('Gagal memilih file', AppColors.error);
    }
  }

  Future<void> _setProof(String path, String name) async {
    final ext = name.split('.').last.toLowerCase();
    if (!_kAllowedExt.contains(ext)) {
      _snack('Format bukti harus JPG, PNG, atau PDF', AppColors.error);
      return;
    }
    if (await File(path).length() > _kMaxProofBytes) {
      _snack('Ukuran bukti maksimal 5 MB', AppColors.error);
      return;
    }
    if (!mounted) return;
    setState(() {
      _proofPath = path;
      _proofName = name;
    });
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _submit() async {
    final notes = _notes.text.trim();
    if (_status == 'sakit' && _proofPath == null) {
      setState(() => _error = 'Bukti (surat dokter/foto) wajib dilampirkan untuk sakit.');
      return;
    }
    if (notes.length > 1000) {
      setState(() => _error = 'Catatan maksimal 1000 karakter.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await ref.read(internRepositoryProvider).leaveRequest(
            date: dateKey(_date),
            status: _status,
            notes: notes,
            proofFilePath: _proofPath,
          );
      ref.invalidate(internTodayProvider);
      ref.invalidate(internHistoryProvider);
      if (!mounted) return;
      setState(() {
        _notes.clear();
        _proofPath = null;
        _proofName = null;
      });
      _snack(message, AppColors.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiException.fromDio(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = internServerToday();
    final history = ref.watch(internHistoryProvider((year: now.year, month: now.month)));

    return Scaffold(
      appBar: AppBar(title: const Text('Pengajuan Izin / Sakit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Jenis', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'izin', label: Text('Izin'), icon: Icon(Icons.event_busy_rounded)),
              ButtonSegment(value: 'sakit', label: Text('Sakit'), icon: Icon(Icons.healing_rounded)),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() {
              _status = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          Text('Tanggal', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text(formatDateFull(_date)),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _notes,
            label: 'Catatan',
            hint: 'Keterangan singkat (opsional)',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text(
            _status == 'sakit' ? 'Bukti (wajib)' : 'Bukti (opsional)',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 2),
          Text(
            'JPG, PNG, atau PDF — maksimal 5 MB',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (_proofName != null)
            Card(
              child: ListTile(
                leading: Icon(
                  _proofName!.toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_rounded,
                  color: AppColors.teal,
                ),
                title: Text(_proofName!, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _proofPath = null;
                    _proofName = null;
                  }),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Kamera'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickPdf,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('File/PDF'),
                ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          AppButton(label: 'Kirim Pengajuan', loading: _submitting, onPressed: _submit),
          const SizedBox(height: 28),
          Text(
            'Pengajuan Bulan Ini',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          history.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(ApiException.fromDio(e).message),
            data: (list) {
              final leaves = list.where((a) => a.isLeave).toList();
              if (leaves.isEmpty) {
                return Text(
                  'Belum ada pengajuan bulan ini.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }
              return Column(
                children: [
                  for (final a in leaves)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text('${a.statusLabel} — ${formatDateLong(a.date)}'),
                        subtitle: a.notes == null ? null : Text(a.notes!, maxLines: 2),
                        trailing: _ApprovalChip(status: a.approvalStatus),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApprovalChip extends StatelessWidget {
  const _ApprovalChip({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };
    return Text(
      internApprovalLabel[status] ?? 'Menunggu',
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
  }
}
