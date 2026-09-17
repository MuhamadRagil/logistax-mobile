import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _number = NumberFormat.decimalPattern('id_ID');

/// 5303988 → "Rp 5.303.988"
String formatRupiah(num? value) => _rupiah.format(value ?? 0);

/// 5303988 → "5.303.988"
String formatNumber(num? value) => _number.format(value ?? 0);
