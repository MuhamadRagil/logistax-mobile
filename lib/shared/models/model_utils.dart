/// Helper parsing JSON — backend mengirim angka Decimal Prisma sebagai string.
num toNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

double toDouble(dynamic v) => toNum(v).toDouble();

int toInt(dynamic v) => toNum(v).toInt();

String? toStr(dynamic v) => v?.toString();
