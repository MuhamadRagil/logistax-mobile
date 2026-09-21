/// Label & teks UI berbahasa Indonesia yang dipakai lintas fitur.
class AppStrings {
  AppStrings._();

  static const appName = 'Logistax';

  static const bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  static const attendanceStatusLabel = {
    'present': 'Hadir',
    'late': 'Terlambat',
    'absent': 'Absen',
    'sick': 'Sakit',
    'izin': 'Izin',
    'cuti': 'Cuti',
    'wfh': 'WFH',
    'holiday': 'Libur',
  };

  static const leaveStatusLabel = {
    'pending': 'Menunggu',
    'approved': 'Disetujui',
    'rejected': 'Ditolak',
    'cancelled': 'Dibatalkan',
  };

  static const kpiTierLabel = {
    'excellent': 'Sangat Baik',
    'good': 'Baik',
    'average': 'Cukup',
    'below_average': 'Perlu Perbaikan',
    'poor': 'Tidak Memuaskan',
  };

  static const loanStatusLabel = {
    'active': 'Aktif',
    'completed': 'Lunas',
    'cancelled': 'Dibatalkan',
  };

  static const employmentStatusLabel = {
    'permanent': 'Karyawan Tetap',
    'contract': 'Kontrak',
    'probation': 'Probation',
    'freelance': 'Freelance',
  };

  static const roleLabel = {
    'super_admin': 'Super Admin',
    'hrd': 'HRD',
    'spv': 'Supervisor',
    'employee': 'Karyawan',
  };

  static const errGeneric = 'Terjadi kesalahan. Coba lagi.';
  static const errNetwork = 'Tidak dapat terhubung ke server. Periksa koneksi Anda.';
}
