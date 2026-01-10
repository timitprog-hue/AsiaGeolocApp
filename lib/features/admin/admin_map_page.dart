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
  // ✅ Modern blue accents (biar konsisten walau theme app beda)
  static const Color primaryBlue = Color(0xFF1E6BFF);

  bool _loading = true; // hanya first load
  bool _busy = false; // apply/refresh tanpa dispose map
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

  // =========================
  // Helpers
  // =========================
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

  // =========================
  // API
  // =========================
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
      } catch (_) {}
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

  // =========================
  // Markers + UI
  // =========================
  Set<Marker> _buildMarkers() {
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isOnline ? primaryBlue : Colors.red).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: (isOnline ? primaryBlue : Colors.red).withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    isOnline ? 'LIVE' : 'OFFLINE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isOnline ? primaryBlue : Colors.red,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
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

  // =========================
  // Lifecycle + polling
  // =========================
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

  // =========================
  // UI widgets
  // =========================
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String selectedName() {
      if (selectedUserId == null) return 'Semua Sales';
      final u = users.where((e) => _asInt(e['id']) == selectedUserId).toList();
      if (u.isEmpty) return 'Sales';
      return (u.first['name'] ?? u.first['email'] ?? 'Sales').toString();
    }

    return AppBar(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(92),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              // ✅ Single header area (hapus "double header"): filter + tombol di appbar bottom
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _busy
                            ? null
                            : () async {
                                final picked = await showModalBottomSheet<int?>(
                                  context: context,
                                  showDragHandle: true,
                                  backgroundColor: cs.surface,
                                  builder: (_) => SafeArea(
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                                          child: Text(
                                            'Pilih Sales',
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                          ),
                                        ),
                                        ListTile(
                                          title: const Text('Semua Sales'),
                                          leading: const Icon(Icons.groups_rounded),
                                          trailing: selectedUserId == null
                                              ? Icon(Icons.check_rounded, color: cs.primary)
                                              : null,
                                          onTap: () => Navigator.pop(context, null),
                                        ),
                                        const Divider(height: 1),
                                        ...users.map((u) {
                                          final id = _asInt(u['id']);
                                          final name = (u['name'] ?? u['email'] ?? 'Sales').toString();
                                          final active = selectedUserId == id;
                                          return ListTile(
                                            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                            leading: const Icon(Icons.person_pin_circle_rounded),
                                            trailing: active ? Icon(Icons.check_rounded, color: cs.primary) : null,
                                            onTap: () => Navigator.pop(context, id),
                                          );
                                        }),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                );

                                if (!mounted) return;
                                setState(() => selectedUserId = picked);
                              },
                        child: Row(
                          children: [
                            const Icon(Icons.filter_alt_rounded, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedName(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Auto refresh 5 detik',
                                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.expand_more_rounded, color: Colors.white.withOpacity(0.95)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _busy ? null : _apply,
                      child: const Text('Terapkan'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Reset',
                      onPressed: _busy ? null : _reset,
                      icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Text(
                      'Sales terpantau: ${liveRows.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_busy)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Memuat...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: Colors.red),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _loadAll,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : Stack(
                  children: [
                    // ✅ Map full (filter udah pindah ke AppBar bottom, jadi header cuma 1)
                    GoogleMap(
                      initialCameraPosition: _initialCam,
                      myLocationButtonEnabled: false,
                      myLocationEnabled: false,
                      zoomControlsEnabled: false,
                      markers: _buildMarkers(),
                      onMapCreated: (c) async {
                        _gmap = c;
                        // fokus ke yang terbaru pas pertama kali map jadi
                        await _loadLiveLocations(moveCameraIfFirst: true);
                      },
                    ),

                    // ✅ floating micro overlay (lebih rapih, modern)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Marker: ${liveRows.length}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
