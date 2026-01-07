import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/api_parser.dart';
import '../reports/report_detail_page.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> users = [];
  List<dynamic> reports = [];

  int? selectedUserId;
  DateTime? dateFrom;
  DateTime? dateTo;

  final _searchCtrl = TextEditingController();
  String _q = '';

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
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
    if (_q.trim().isNotEmpty) qp['q'] = _q.trim();

    final res = await api.dio.get('/reports', queryParameters: qp);
    reports = ApiParser.extractList(res.data);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadUsers();
      await _loadReports();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat.\n$e';
        _loading = false;
      });
    }
  }

  Future<void> _apply() async {
    setState(() => _loading = true);
    try {
      await _loadReports();
    } catch (e) {
      _error = 'Gagal memuat.\n$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      selectedUserId = null;
      dateFrom = null;
      dateTo = null;
      _q = '';
      _searchCtrl.clear();
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
        // auto-fix kalau dateTo < dateFrom
        if (dateTo != null && dateTo!.isBefore(dateFrom!)) dateTo = dateFrom;
      } else {
        dateTo = picked;
        if (dateFrom != null && dateTo!.isBefore(dateFrom!)) dateFrom = dateTo;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Reports')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      // ===== FILTER CARD =====
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Filter', style: TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),

                              // Search
                              TextField(
                                controller: _searchCtrl,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) {
                                  setState(() => _q = _searchCtrl.text);
                                  _apply();
                                },
                                decoration: InputDecoration(
                                  labelText: 'Cari alamat / catatan',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _searchCtrl.text.trim().isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() => _q = '');
                                            _apply();
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                                onChanged: (v) {
                                  // biar suffixIcon update
                                  setState(() {});
                                },
                              ),

                              const SizedBox(height: 12),

                              // Sales dropdown
                              DropdownButtonFormField<int?>(
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
                                      child: Text(name),
                                    );
                                  }),
                                ],
                                onChanged: (v) => setState(() => selectedUserId = v),
                                decoration: const InputDecoration(labelText: 'Sales'),
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _pickDate(from: true),
                                      icon: const Icon(Icons.date_range_rounded),
                                      label: Text(dateFrom == null ? 'Dari tanggal' : _fmtDateOnly(dateFrom!)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _pickDate(from: false),
                                      icon: const Icon(Icons.date_range_rounded),
                                      label: Text(dateTo == null ? 'Sampai tanggal' : _fmtDateOnly(dateTo!)),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _apply,
                                      icon: const Icon(Icons.filter_alt_rounded),
                                      label: const Text('Terapkan'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _reset,
                                      child: const Text('Reset'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Hasil: ${reports.length}',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 8),

                      if (reports.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline_rounded),
                                SizedBox(width: 10),
                                Expanded(child: Text('Tidak ada report pada filter ini.')),
                              ],
                            ),
                          ),
                        )
                      else
                        ...reports.map((r) {
                          if (r is! Map) return const SizedBox.shrink();
                          final rr = r.cast<String, dynamic>();

                          final id = _asInt(rr['id']);
                          final address = (rr['address']?.toString().trim().isNotEmpty == true)
                              ? rr['address'].toString()
                              : 'Alamat belum tersedia';
                          final time = _fmtDate(rr['captured_at'] ?? rr['created_at']);

                          // ✅ tampilkan nama sales (kalau backend include user)
                          final userObj = rr['user'];
                          String salesName = 'Sales';
                          if (userObj is Map) {
                            final u = userObj.cast<String, dynamic>();
                            salesName = (u['name'] ?? u['email'] ?? 'Sales').toString();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.place_rounded, color: cs.primary),
                                ),
                                title: Text(
                                  address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text('$salesName • $time'),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: id <= 0
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => ReportDetailPage(reportId: id)),
                                        ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
