import '../constants/app_strings.dart';

/// "2026-07-20" / DateTime → "20 Juli 2026"
String formatDateLong(dynamic value) {
  final d = _parse(value);
  if (d == null) return '-';
  return '${d.day} ${AppStrings.bulan[d.month - 1]} ${d.year}';
}

/// → "Senin, 20 Juli 2026"
String formatDateFull(dynamic value) {
  final d = _parse(value);
  if (d == null) return '-';
  return '${AppStrings.hari[d.weekday - 1]}, ${formatDateLong(d)}';
}

/// → "20 Jul 2026"
String formatDateShort(dynamic value) {
  final d = _parse(value);
  if (d == null) return '-';
  return '${d.day} ${AppStrings.bulan[d.month - 1].substring(0, 3)} ${d.year}';
}

/// Jam lokal (WIB di device Indonesia) → "09:05"
String formatTime(dynamic value) {
  final d = _parse(value);
  if (d == null) return '-';
  final local = d.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// → "09:05 WIB"
String formatTimeWib(dynamic value) {
  final t = formatTime(value);
  return t == '-' ? t : '$t WIB';
}

/// (7, 2026) → "Juli 2026"
String monthLabel(int month, int year) => '${AppStrings.bulan[month - 1]} $year';

/// → "2026-07-20" untuk dikirim ke API.
String toApiDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Hitung hari kerja (Senin–Jumat) inklusif antara dua tanggal.
int countWorkingDays(DateTime start, DateTime end) {
  if (end.isBefore(start)) return 0;
  var count = 0;
  var d = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!d.isAfter(last)) {
    if (d.weekday <= 5) count++;
    d = d.add(const Duration(days: 1));
  }
  return count;
}

DateTime? _parse(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
