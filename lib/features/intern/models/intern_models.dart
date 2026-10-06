import 'dart:convert';

import '../../../shared/models/model_utils.dart';

/// Zona waktu backend magang (APP_TIMEZONE=Asia/Jakarta, tanpa DST).
const _kServerOffset = Duration(hours: 7);

/// Tanggal dari backend magang → "yyyy-MM-dd".
///
/// Laravel menserialisasi kolom `date` sebagai instant UTC dari tengah malam
/// zona waktu server: dengan Asia/Jakarta, tanggal 24 Sep dikirim sebagai
/// "2026-09-23T17:00:00.000000Z". Karena itu instant dikonversi ke WIB dulu
/// — memotong 10 karakter pertama akan meleset sehari. Konversi ini juga
/// benar bila server masih UTC ("…T00:00:00Z" + 7 jam = hari yang sama).
/// Nilai yang sudah "yyyy-MM-dd" dipakai apa adanya. Tidak memakai zona waktu
/// device, supaya hasilnya sama di HP yang zonanya bukan WIB.
String? dateKeyOf(dynamic value) {
  final s = value?.toString();
  if (s == null || s.length < 10) return null;
  if (s.length == 10) return s;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return s.substring(0, 10);
  return dateKey(parsed.toUtc().add(_kServerOffset));
}

String _pad(int v) => v.toString().padLeft(2, '0');

String dateKey(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

/// "Hari ini" versi backend magang (`Carbon::today()` = tanggal WIB), dalam
/// bentuk DateTime UTC yang komponen tanggalnya adalah tanggal WIB.
DateTime internServerToday() => DateTime.now().toUtc().add(_kServerOffset);

const internStatusLabel = {
  'pending': 'Menunggu Persetujuan',
  'active': 'Aktif',
  'extended': 'Diperpanjang',
  'completed': 'Selesai',
  'failed': 'Tidak Lulus',
  'rejected': 'Ditolak',
};

const internAttendanceStatusLabel = {
  'hadir': 'Hadir',
  'izin': 'Izin',
  'sakit': 'Sakit',
  'absen': 'Absen',
};

const internApprovalLabel = {
  'pending': 'Menunggu persetujuan',
  'approved': 'Disetujui',
  'rejected': 'Ditolak',
};

/// Data diri intern — hanya tersedia dari response login (backend magang
/// tidak punya endpoint profil untuk intern), disimpan lokal selama sesi.
class InternProfile {
  final String id;
  final String fullName;
  final String nim;
  final String? institution;
  final String? major;
  final String? phone;
  final String? photoUrl;
  final String? startDate; // yyyy-MM-dd
  final String? endDate; // yyyy-MM-dd
  final String status;

  const InternProfile({
    required this.id,
    required this.fullName,
    required this.nim,
    this.institution,
    this.major,
    this.phone,
    this.photoUrl,
    this.startDate,
    this.endDate,
    required this.status,
  });

  String get statusLabel => internStatusLabel[status] ?? status;

  /// Aktif atau diperpanjang — hanya status ini yang boleh check-in.
  bool get canAttend => status == 'active' || status == 'extended';

  /// Sisa hari kalender sampai `end_date` (inklusif hari ini = 0 bila
  /// berakhir hari ini). Null bila periode belum diatur.
  int? remainingDays(DateTime now) {
    final end = endDate == null ? null : DateTime.tryParse(endDate!);
    if (end == null) return null;
    final today = DateTime.utc(now.year, now.month, now.day);
    final last = DateTime.utc(end.year, end.month, end.day);
    final diff = last.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory InternProfile.fromJson(Map<String, dynamic> json) => InternProfile(
        id: toStr(json['id']) ?? '',
        fullName: toStr(json['full_name']) ?? '',
        nim: toStr(json['nim']) ?? '',
        institution: toStr(json['institution']),
        major: toStr(json['major']),
        phone: toStr(json['phone']),
        photoUrl: toStr(json['photo_url']),
        startDate: dateKeyOf(json['start_date']),
        endDate: dateKeyOf(json['end_date']),
        status: toStr(json['status']) ?? 'pending',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'nim': nim,
        'institution': institution,
        'major': major,
        'phone': phone,
        'photo_url': photoUrl,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
      };

  String encode() => jsonEncode(toJson());

  static InternProfile? decode(String? raw) {
    if (raw == null) return null;
    try {
      return InternProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class InternAttendance {
  final String id;
  final String? date; // yyyy-MM-dd (tanggal versi server/UTC)
  final String? checkInTime; // ISO UTC
  final String? checkOutTime;
  final String status; // hadir | izin | sakit | absen
  final String? approvalStatus; // pending | approved | rejected (izin/sakit)
  final String? notes;
  final String? proofFileUrl;

  const InternAttendance({
    required this.id,
    this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.approvalStatus,
    this.notes,
    this.proofFileUrl,
  });

  bool get hasCheckedIn => checkInTime != null;
  bool get hasCheckedOut => checkOutTime != null;
  bool get isLeave => status == 'izin' || status == 'sakit';

  String get statusLabel => internAttendanceStatusLabel[status] ?? status;

  factory InternAttendance.fromJson(Map<String, dynamic> json) => InternAttendance(
        id: toStr(json['id']) ?? '',
        date: dateKeyOf(json['date']),
        checkInTime: toStr(json['check_in_time']),
        checkOutTime: toStr(json['check_out_time']),
        status: toStr(json['status']) ?? '',
        approvalStatus: toStr(json['approval_status']),
        notes: toStr(json['notes']),
        proofFileUrl: toStr(json['proof_file_url']),
      );
}

class InternEvaluation {
  final double discipline;
  final double performance;
  final double attitude;
  final double communication;
  final double total;
  final String? grade;
  final String? comments;

  const InternEvaluation({
    required this.discipline,
    required this.performance,
    required this.attitude,
    required this.communication,
    required this.total,
    this.grade,
    this.comments,
  });

  /// Skor desimal dikirim Laravel sebagai string ("85.50") — `toDouble`
  /// menangani string maupun angka.
  factory InternEvaluation.fromJson(Map<String, dynamic> json) => InternEvaluation(
        discipline: toDouble(json['discipline_score']),
        performance: toDouble(json['performance_score']),
        attitude: toDouble(json['attitude_score']),
        communication: toDouble(json['communication_score']),
        total: toDouble(json['total_score']),
        grade: toStr(json['grade']),
        comments: toStr(json['comments']),
      );
}

class InternCertificate {
  final String? certificateNumber;
  final String? issuedDate; // yyyy-MM-dd
  final String? issuedCity;

  const InternCertificate({this.certificateNumber, this.issuedDate, this.issuedCity});

  factory InternCertificate.fromJson(Map<String, dynamic> json) => InternCertificate(
        certificateNumber: toStr(json['certificate_number']),
        issuedDate: dateKeyOf(json['issued_date']),
        issuedCity: toStr(json['issued_city']),
      );
}
