import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../providers/profile_provider.dart';

/// Halaman "Edit Profil" — karyawan bisa mengubah foto, nomor HP & alamat
/// sendiri (PATCH /employees/me/profile & /employees/me/photo). Nama, NIK,
/// dan jabatan tetap readonly karena wewenang HRD.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _fullName = TextEditingController();
  final _nik = TextEditingController();
  final _position = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  bool _fieldsLoaded = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _fullName.dispose();
    _nik.dispose();
    _position.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
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
            phone: _phone.text.trim(),
            address: _address.text.trim(),
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
    final theme = Theme.of(context);
    final async = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingShimmer(count: 5, height: 70),
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

          _fullName.text = profile.fullName.isEmpty ? '-' : profile.fullName;
          _nik.text = profile.nik.isEmpty ? '-' : profile.nik;
          _position.text = profile.positionName ?? '-';
          // Hanya isi sekali dari server — supaya ketikan user tidak
          // tertimpa saat provider di-invalidate ulang (mis. setelah save).
          if (!_fieldsLoaded) {
            _phone.text = profile.phone ?? '';
            _address.text = profile.address ?? '';
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
              const SizedBox(height: 24),
              Text(
                'Data Karyawan',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _fullName, label: 'Nama Lengkap', enabled: false),
              const SizedBox(height: 14),
              AppTextField(controller: _nik, label: 'NIK', enabled: false),
              const SizedBox(height: 14),
              AppTextField(controller: _position, label: 'Jabatan', enabled: false),
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
