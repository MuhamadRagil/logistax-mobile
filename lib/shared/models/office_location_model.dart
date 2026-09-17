import 'model_utils.dart';

/// Lokasi kantor tempat karyawan boleh absen (multi-lokasi).
class OfficeLocation {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  const OfficeLocation({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory OfficeLocation.fromJson(Map<String, dynamic> json) => OfficeLocation(
        id: toStr(json['id']) ?? '',
        name: toStr(json['name']) ?? '-',
        address: toStr(json['address']),
        latitude: toDouble(json['latitude']),
        longitude: toDouble(json['longitude']),
        radiusMeters: toInt(json['radiusMeters']),
      );
}
