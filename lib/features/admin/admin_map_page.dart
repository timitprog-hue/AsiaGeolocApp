import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';

class AdminMapPage extends StatefulWidget {
  const AdminMapPage({super.key});

  @override
  State<AdminMapPage> createState() => _AdminMapPageState();
}

class _AdminMapPageState extends State<AdminMapPage> {
  bool _loading = true; // hanya untuk first load
  bool _busy = false; // untuk apply / refresh tanpa dispose map
  String? _error;

  // filters
  List<Map<String, dynamic>> users = [];
  int? selectedUserId;

  // live locations (latest)
  List<Map<String, dynamic>> liveRows = [];

  GoogleMapController? _gmap;
  final CameraPosition _initialCam = const CameraPosition(
    target: LatLng(-7.2575, 112.7521), // Surabaya fallback
    zoom: 12.5,
  );

  Timer? _pollTimer;
  bool _polling = false;

  // cache alamat (reverse geocode)
  final Map<String, String> _addrCache = {}; // key: "lat,lng"

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      try {
        return DateFormat("yyyy-MM-dd HH:mm:ss").parse(raw.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }
  }

  String _fmtTime(dynamic raw) {
    final dt = _parseDate(raw);
    if (dt == null) return '-';
    return DateFormat("dd MMM • HH:mm:ss").format(dt);
  }

  Future<void> _loadUsers() async {
    final storage = AuthStorage();
    final api = ApiClient(storage);

    final res = await api.dio.get('/users', queryParameters: {'role': 'sales'});
    final data = (res.data['data'] as List<dynamic>?) ?? [];
    users = data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> _loadLiveLocations({bool moveCameraIfFirst = false}) async {
    final storage = AuthStorage();
    final api = ApiClient(storage);

    final qp = <String, dynamic>{};
    if (selectedUserId != null) qp['user_id'] = selectedUserId;

    final res = await api.dio.get('/live-locations', queryParameters: qp);
    final list = (res.data['data'] as List<dynamic>?) ?? [];

    final out = <Map<String, dynamic>>[];
    for (final it in list) {
      if (it is! Map) continue;
      final r = it.cast<String, dynamic>();

      final lat = _asDouble(r['latitude']);
      final lng = _asDouble(r['longitude']);
      if (lat == null || lng == null) continue;

      out.add(r);
    }

    // urutkan: yang terbaru update dulu
    out.sort((a, b) {
      final da = _parseDate(a['updated_at'] ?? a['captured_at']) ?? DateTime(1970);
      final db = _parseDate(b['updated_at'] ?? b['captured_at']) ?? DateTime(1970);
      return db.compareTo(da);
    });

    liveRows = out;

    // center ke yang pertama (terbaru)
    if (moveCameraIfFirst && liveRows.isNotEmpty && _gmap != null && mounted) {
      final lat = _asDouble(liveRows.first['latitude'])!;
      final lng = _asDouble(liveRows.first['longitude'])!;
      try {
        await _gmap!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.2),
        );
      } catch (_) {
        // ignore (controller bisa invalid kalau map lagi rebuild)
      }
    }

    if (mounted) setState(() {});
  }

  Future<String> _resolveAddress(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    final cached = _addrCache[key];
    if (cached != null) return cached;

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return 'Alamat tidak tersedia';

      final pm = placemarks.first;
      final parts = <String>[
        if ((pm.street ?? '').isNotEmpty) pm.street!,
        if ((pm.subLocality ?? '').isNotEmpty) pm.subLocality!,
        if ((pm.locality ?? '').isNotEmpty) pm.locality!,
        if ((pm.administrativeArea ?? '').isNotEmpty) pm.administrativeArea!,
      ];

      final addr = parts.isEmpty ? 'Alamat tidak tersedia' : parts.join(', ');
      _addrCache[key] = addr;
      return addr;
    } catch (_) {
      return 'Alamat tidak tersedia';
    }
  }

  Set<Marker> _buildMarkers(BuildContext context) {
    return liveRows.map((r) {
      final user = r['user'];
      String name = 'Sales';
      int uid = _asInt(r['user_id']);
      if (user is Map) {
        final u = user.cast<String, dynamic>();
        name = (u['name'] ?? u['email'] ?? 'Sales').toString();
        uid = _asInt(u['id'] ?? uid);
      }

      final lat = _asDouble(r['latitude'])!;
      final lng = _asDouble(r['longitude'])!;
      final updated = _fmtTime(r['updated_at'] ?? r['captured_at']);
      final isOnline = (r['is_online'] == true);

      return Marker(
        markerId: MarkerId('u:$uid'),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: '$name${isOnline ? ' • LIVE' : ' • OFFLINE'}',
          snippet: 'Update: $updated',
          onTap: () => _openLiveSheet(r),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isOnline ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
        ),
      );
    }).toSet();
  }

  void _openLiveSheet(Map<String, dynamic> r) {
    final user = r['user'];
    String name = 'Sales';
    if (user is Map) {
      final u = user.cast<String, dynamic>();
      name = (u['name'] ?? u['email'] ?? 'Sales').toString();
    }

    final lat = _asDouble(r['latitude']);
    final lng = _asDouble(r['longitude']);
    final acc = r['accuracy_m']?.toString() ?? '-';
    final updated = _fmtTime(r['updated_at'] ?? r['captured_at']);
    final isOnline = (r['is_online'] == true);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(isOnline ? 'Status: LIVE' : 'Status: OFFLINE'),
            const SizedBox(height: 6),
            Text('Update: $updated'),
            const SizedBox(height: 10),

            if (lat != null && lng != null)
              FutureBuilder<String>(
                future: _resolveAddress(lat, lng),
                builder: (context, snap) {
                  final addr = snap.data;
                  return Text(
                    addr == null ? 'Alamat: memuat...' : 'Alamat: $addr',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  );
                },
              ),
            const SizedBox(height: 6),
            Text('LatLng: ${lat ?? '-'}, ${lng ?? '-'} • Acc: $acc m'),

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (lat == null || lng == null || _gmap == null)
                        ? null
                        : () async {
                            Navigator.pop(context);
                            try {
                              await _gmap!.animateCamera(
                                CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.5),
                              );
                            } catch (_) {}
                          },
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    label: const Text('Fokus ke Sales'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _busy = false;
      _error = null;
    });

    try {
      await _loadUsers();
      await _loadLiveLocations(moveCameraIfFirst: false);

      if (!mounted) return;
      setState(() => _loading = false);

      _startPolling(); // auto refresh
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat map.\n$e';
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_polling) return;
      _polling = true;
      try {
        await _loadLiveLocations(moveCameraIfFirst: false);
      } finally {
        _polling = false;
      }
    });
  }

  Future<void> _apply() async {
    // ✅ jangan set _loading = true, biar map gak disposed
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _loadLiveLocations(moveCameraIfFirst: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat lokasi live.\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() => selectedUserId = null);
    await _apply();
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _gmap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map (Sales)'),
        actions: [
          IconButton(
            onPressed: () async {
              setState(() => _busy = true);
              try {
                await _loadLiveLocations(moveCameraIfFirst: false);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Stack(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int?>(
                                          value: selectedUserId,
                                          items: [
                                            const DropdownMenuItem<int?>(
                                              value: null,
                                              child: Text('Semua Sales'),
                                            ),
                                            ...users.map((u) {
                                              final id = _asInt(u['id']);
                                              final name = (u['name'] ?? u['email'] ?? 'Sales').toString();
                                              return DropdownMenuItem<int?>(
                                                value: id,
                                                child: Text(name, overflow: TextOverflow.ellipsis),
                                              );
                                            }),
                                          ],
                                          onChanged: (v) => setState(() => selectedUserId = v),
                                          decoration: const InputDecoration(labelText: 'Sales'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton(
                                        onPressed: _busy ? null : _apply,
                                        child: const Text('Terapkan'),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        onPressed: _busy ? null : _reset,
                                        icon: Icon(Icons.restart_alt_rounded, color: cs.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Sales terpantau: ${liveRows.length} (auto refresh 5 detik)',
                                      style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GoogleMap(
                            initialCameraPosition: _initialCam,
                            myLocationButtonEnabled: false,
                            myLocationEnabled: false,
                            zoomControlsEnabled: false,
                            markers: _buildMarkers(context),
                            onMapCreated: (c) async {
                              _gmap = c;
                              // fokus ke yang terbaru pas pertama kali map jadi
                              await _loadLiveLocations(moveCameraIfFirst: true);
                            },
                          ),
                        ),
                      ],
                    ),

                    // overlay loading kecil biar map gak ke-dispose
                    if (_busy)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Memuat...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
