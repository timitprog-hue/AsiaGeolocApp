import 'package:geocoding/geocoding.dart';

class LocationHelper {
  static Future<String?> toAddress(double lat, double lng) async {
    try {
      final list = await placemarkFromCoordinates(lat, lng);
      if (list.isEmpty) return null;
      final p = list.first;

      final parts = <String>[
        if ((p.street ?? '').isNotEmpty) p.street!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.subAdministrativeArea ?? '').isNotEmpty) p.subAdministrativeArea!,
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
      ];

      final s = parts.join(', ').trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }
}
