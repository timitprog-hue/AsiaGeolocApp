import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/api_parser.dart';
import '../reports/report_detail_page.dart';

class AdminMapPage extends StatefulWidget {
  const AdminMapPage({super.key});

  @override
  State<AdminMapPage> createState() => _AdminMapPageState();
}

class _AdminMapPageState extends State<AdminMapPage> {
  bool _loading = true;
  String? _error;

  // filters
  List<Map<String, dynamic>> users = [];
  int? selectedUserId;
  DateTime? dateFrom;
  DateTime? dateTo;

  // data
  List<Map<String, dynamic>> reports = [];

  // map
  final MapController _map = MapController();
  LatLng _center = const LatLng(-7.2575, 112.7521); // fallback Surabaya
  double _zoom = 12.5;

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

  String _fmtDate(dynamic v) {
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return DateFormat("dd MMM yyyy • HH:mm").format(dt);
    } catch (_) {
      return v?.toString() ?? '-';
    }
  }

  String _fmtDateOnly(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadUsers() async {
    final storage = AuthStorage();
    final api = ApiClient(storage);

    final res = await api.dio.get('/users', queryParameters: {'role': 'sales'});
    final data = (res.data['data'] as List<dynamic>?) ?? [];
    users = data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> _loadReports() async {
    final storage = AuthStorage();
    final api = ApiClient(storage);

    final qp = <String, dynamic>{};
    if (selectedUserId != null) qp['user_id'] = selectedUserId;
    if (dateFrom != null) qp['date_from'] = _fmtDateOnly(dateFrom!);
    if (dateTo != null) qp['date_to'] = _fmtDateOnly(dateTo!);

    final res = await api.dio.get('/reports', queryParameters: qp);
    final list = ApiParser.extractList(res.data);

    final out = <Map<String, dynamic>>[];
    for (final it in list) {
      if (it is! Map) continue;
      final r = it.cast<String, dynamic>();

      final lat = _asDouble(r['latitude']);
      final lng = _asDouble(r['longitude']);
      if (lat == null || lng == null) continue; // skip invalid

      out.add(r);
    }

    // urutkan terbaru dulu
    out.sort((a, b) {
      final da = _parseDate(a['captured_at'] ?? a['created_at']) ?? DateTime(1970);
      final db = _parseDate(b['captured_at'] ?? b['created_at']) ?? DateTime(1970);
      return db.compareTo(da);
    });

    reports = out;

    // set center ke report terbaru
    if (reports.isNotEmpty) {
      final lat = _asDouble(reports.first['latitude'])!;
      final lng = _asDouble(reports.first['longitude'])!;
      _center = LatLng(lat, lng);
      _zoom = 13.2;
    }
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

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadUsers();
      await _loadReports();

      if (mounted) {
        setState(() => _loading = false);
        // geser kamera setelah UI siap
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _map.move(_center, _zoom);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat map.\n$e';
        _loading = false;
      });
    }
  }

  Future<void> _apply() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadReports();
      if (!mounted) return;
      setState(() => _loading = false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _map.move(_center, _zoom);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat map.\n$e';
        _loading = false;
      });
    }
  }

  Future<void> _reset() async {
    setState(() {
      selectedUserId = null;
      dateFrom = null;
      dateTo = null;
    });
    await _apply();
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final initial = (from ? dateFrom : dateTo) ?? now;

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDate: initial,
    );
    if (picked == null) return;

    setState(() {
      if (from) {
        dateFrom = picked;
        if (dateTo != null && dateTo!.isBefore(dateFrom!)) dateTo = dateFrom;
      } else {
        dateTo = picked;
        if (dateFrom != null && dateTo!.isBefore(dateFrom!)) dateFrom = dateTo;
      }
    });
  }

  void _openReportSheet(Map<String, dynamic> r) {
    final id = _asInt(r['id']);

    final address = (r['address']?.toString().trim().isNotEmpty == true)
        ? r['address'].toString()
        : 'Alamat belum tersedia';

    final time = _fmtDate(r['captured_at'] ?? r['created_at']);

    // ✅ nama sales kalau backend include user
    final userObj = r['user'];
    String salesName = 'Sales';
    if (userObj is Map) {
      final u = userObj.cast<String, dynamic>();
      salesName = (u['name'] ?? u['email'] ?? 'Sales').toString();
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(address, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              Text('$salesName • $time'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: id <= 0
                          ? null
                          : () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ReportDetailPage(reportId: id)),
                              );
                            },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Buka Detail'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<Marker> _buildMarkers(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return reports.map((r) {
      final lat = _asDouble(r['latitude'])!;
      final lng = _asDouble(r['longitude'])!;
      return Marker(
        point: LatLng(lat, lng),
        width: 46,
        height: 46,
        child: GestureDetector(
          onTap: () => _openReportSheet(r),
          child: Container(
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: const Icon(Icons.location_on_rounded, color: Colors.white),
          ),
        ),
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    // ===== FILTER BAR =====
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
                                    onPressed: _apply,
                                    child: const Text('Terapkan'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _pickDate(from: true),
                                      icon: const Icon(Icons.date_range_rounded),
                                      label: Text(dateFrom == null ? 'Dari' : _fmtDateOnly(dateFrom!)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _pickDate(from: false),
                                      icon: const Icon(Icons.date_range_rounded),
                                      label: Text(dateTo == null ? 'Sampai' : _fmtDateOnly(dateTo!)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _reset,
                                    icon: Icon(Icons.restart_alt_rounded, color: cs.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Marker: ${reports.length}',
                                  style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ===== MAP =====
                    Expanded(
                      child: FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: _zoom,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'asia_geoloc_app',
                          ),
                          MarkerLayer(markers: _buildMarkers(context)),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
