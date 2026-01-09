import 'dart:async';
import 'package:geolocator/geolocator.dart';

import 'api_client.dart';
import 'auth_storage.dart';

class LiveLocationService {
  Timer? _timer;
  bool _sending = false;

  Future<bool> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  void start({Duration interval = const Duration(seconds: 10)}) {
    stop();
    _timer = Timer.periodic(interval, (_) => sendOnce());
    sendOnce(); // kirim pertama langsung
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> sendOnce() async {
    if (_sending) return;
    _sending = true;

    try {
      final ok = await _ensurePermission();
      if (!ok) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final storage = AuthStorage();
      final api = ApiClient(storage);

      await api.dio.post('/live-locations', data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy_m': pos.accuracy,
        'captured_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // biarin dulu, biar ga spam error di UI
    } finally {
      _sending = false;
    }
  }
}
