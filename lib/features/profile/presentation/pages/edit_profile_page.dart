import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_util.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../providers/profile_provider.dart';

/// Halaman "Edit Profil" — karyawan bisa mengubah data pribadi & keuangan
/// miliknya sendiri (PATCH /employees/me/profile & /employees/me/photo).
/// NIK, jabatan, departemen, status kepegawaian, dan tanggal masuk tetap
/// readonly karena wewenang HRD.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  // Editable
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccountNumber = TextEditingController();
  final _npwp = TextEditingController();
  final _bpjsKesehatan = TextEditingController();
  final _bpjsTk = TextEditingController();
  DateTime? _birthDate;
  String? _gender; // 'male' | 'female'

  // Readonly (Informasi Pekerjaan)
  final _nik = TextEditingController();
  final _position = TextEditingController();
  final _department = TextEditingController();
  final _employmentStatus = TextEditingController();
  final _hireDate = TextEditingController();

  bool _fieldsLoaded = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _address.dispose();
    _bankName.dispose();
    _bankAccountNumber.dispose();
    _npwp.dispose();
    _bpjsKesehatan.dispose();
    _bpjsTk.dispose();
    _nik.dispose();
    _position.dispose();
    _department.dispose();
    _employmentStatus.dispose();
    _hireDate.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 15),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final photo = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1200);
    if (photo == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      await ref.read(profileRepositoryProvider).uploadMyPhoto(photo.path);
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDio(e).message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
            fullName: _fullName.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            gender: _gender,
            birthDate: _birthDate != null ? toApiDate(_birthDate!) : null,
            bankName: _bankName.text.trim(),
            bankAccountNumber: _bankAccountNumber.text.trim(),
            npwp: _npwp.text.trim(),
            bpjsKesehatan: _bpjsKesehatan.text.trim(),
            bpjsTk: _bpjsTk.text.trim(),
          );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDio(e).message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingShimmer(count: 6, height: 70),
        ),
        error: (error, _) =>
            ErrorState(error: error, onRetry: () => ref.invalidate(myProfileProvider)),
        data: (profile) {
          if (profile == null) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: EmptyState(
                icon: Icons.person_off_rounded,
                title: 'Akun tidak terhubung dengan data karyawan',
                description: 'Hubungi HRD untuk menghubungkan akun Anda.',
              ),
            );
          }

          // Readonly — selalu sinkron dengan data server, aman diisi tiap build.
          _nik.text = profile.nik.isEmpty ? '-' : profile.nik;
          _position.text = profile.positionName ?? '-';
          _department.text = profile.departmentName ?? '-';
          _employmentStatus.text =
              AppStrings.employmentStatusLabel[profile.employmentStatus] ?? profile.employmentStatus;
          _hireDate.text = formatDateLong(profile.hireDate);

          // Editable — hanya isi sekali dari server supaya ketikan user tidak
          // tertimpa saat provider di-invalidate ulang (mis. setelah save).
          if (!_fieldsLoaded) {
            _fullName.text = profile.fullName;
            _phone.text = profile.phone ?? '';
            _address.text = profile.address ?? '';
            _bankName.text = profile.bankName ?? '';
            _bankAccountNumber.text = profile.bankAccountNumber ?? '';
            _npwp.text = profile.npwp ?? '';
            _bpjsKesehatan.text = profile.bpjsKesehatan ?? '';
            _bpjsTk.text = profile.bpjsTk ?? '';
            _gender = (profile.gender == 'male' || profile.gender == 'female') ? profile.gender : null;
            _birthDate = DateTime.tryParse(profile.birthDate ?? '');
            _fieldsLoaded = true;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.tealLight,
                      backgroundImage: (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(profile.photoUrl!)
                          : null,
                      child: (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 44, color: AppColors.teal)
                          : null,
                    ),
                    if (_uploadingPhoto)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.black45,
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap: _uploadingPhoto ? null : _changePhoto,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.navy,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _SectionTitle('Informasi Pribadi'),
              const SizedBox(height: 12),
              AppTextField(controller: _fullName, label: 'Nama Lengkap'),
              const SizedBox(height: 14),
              AppTextField(
                controller: _phone,
                label: 'Nomor HP',
                hint: '08xxxxxxxxxx',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _address,
                label: 'Alamat',
                hint: 'Alamat tempat tinggal',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Jenis Kelamin',
                  prefixIcon: Icon(Icons.wc_rounded),
                ),
                hint: const Text('Pilih jenis kelamin'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Laki-laki')),
                  DropdownMenuItem(value: 'female', child: Text('Perempuan')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 14),
              _DateField(
                label: 'Tanggal Lahir',
                value: _birthDate == null ? null : formatDateSlash(_birthDate),
                onTap: _pickBirthDate,
              ),

              const SizedBox(height: 24),
              _SectionTitle('Informasi Keuangan'),
              const SizedBox(height: 12),
              AppTextField(controller: _bankName, label: 'Nama Bank', hint: 'mis. BCA'),
              const SizedBox(height: 14),
              AppTextField(
                controller: _bankAccountNumber,
                label: 'Nomor Rekening',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              AppTextField(controller: _npwp, label: 'NPWP'),

              const SizedBox(height: 24),
              _SectionTitle('Data BPJS'),
              const SizedBox(height: 12),
              AppTextField(
                controller: _bpjsKesehatan,
                label: 'BPJS Kesehatan',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _bpjsTk,
                label: 'BPJS Ketenagakerjaan',
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 24),
              _SectionTitle('Informasi Pekerjaan'),
              const SizedBox(height: 12),
              AppTextField(controller: _nik, label: 'NIK', enabled: false),
              const SizedBox(height: 14),
              AppTextField(controller: _position, label: 'Jabatan', enabled: false),
              const SizedBox(height: 14),
              AppTextField(controller: _department, label: 'Departemen', enabled: false),
              const SizedBox(height: 14),
              AppTextField(
                controller: _employmentStatus,
                label: 'Status Kepegawaian',
                enabled: false,
              ),
              const SizedBox(height: 14),
              AppTextField(controller: _hireDate, label: 'Tanggal Masuk', enabled: false),

              const SizedBox(height: 24),
              AppButton(
                label: 'Simpan Perubahan',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.cake_outlined),
        ),
        child: Text(
          value ?? 'Pilih tanggal',
          style: value == null
              ? theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              : theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
