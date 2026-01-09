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
      builder: (context, child) {
        // tema biru buat date picker
        final cs = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: cs.copyWith(
              primary: const Color(0xFF1D4ED8), // blue-700
              secondary: const Color(0xFF1D4ED8),
            ),
          ),
          child: child!,
        );
      },
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

  // ======= UI HELPERS (BIAR RAPI) =======
  Color get _blue => const Color(0xFF1D4ED8); // modern blue
  Color get _bg => const Color(0xFFF6F8FF); // soft blue-ish background
  BorderRadius get _r => BorderRadius.circular(20);

  InputDecoration _inputDec({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _blue.withOpacity(0.9), width: 1.4),
      ),
    );
  }

  Widget _chipButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool active,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _blue.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? _blue : Colors.black54),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: active ? _blue : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _ghostButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _blue,
        side: BorderSide(color: _blue.withOpacity(0.25)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }

@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  return Scaffold(
    backgroundColor: _bg,

    // ✅ HAPUS appBar BIAR GA ADA BAR ATAS
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: _r),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: cs.error),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    children: [
                      // ===== HEADER CARD =====
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: _r,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _blue.withOpacity(0.95),
                              const Color(0xFF2563EB).withOpacity(0.85),
                              const Color(0xFF60A5FA).withOpacity(0.55),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _blue.withOpacity(0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.22)),
                              ),
                              child: const Icon(Icons.map_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Monitoring Laporan Sales',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total hasil: ${reports.length}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== FILTER CARD =====
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: _r),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _blue.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(Icons.tune_rounded, color: _blue),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Filter',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                    ),
                                  ),
                                  if (_q.isNotEmpty || selectedUserId != null || dateFrom != null || dateTo != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _blue.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: _blue.withOpacity(0.18)),
                                      ),
                                      child: Text(
                                        'Aktif',
                                        style: TextStyle(color: _blue, fontWeight: FontWeight.w800, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Search
                              TextField(
                                controller: _searchCtrl,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) {
                                  setState(() => _q = _searchCtrl.text);
                                  _apply();
                                },
                                decoration: _inputDec(
                                  label: 'Cari alamat / catatan',
                                  icon: Icons.search_rounded,
                                  suffix: _searchCtrl.text.trim().isEmpty
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
                                onChanged: (_) => setState(() {}),
                              ),

                              const SizedBox(height: 12),

                              // Sales dropdown
                              DropdownButtonFormField<int?>(
                                value: selectedUserId,
                                isExpanded: true,
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
                                decoration: _inputDec(label: 'Sales', icon: Icons.person_rounded),
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: _chipButton(
                                      label: dateFrom == null ? 'Dari tanggal' : _fmtDateOnly(dateFrom!),
                                      icon: Icons.calendar_month_rounded,
                                      active: dateFrom != null,
                                      onTap: () => _pickDate(from: true),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _chipButton(
                                      label: dateTo == null ? 'Sampai tanggal' : _fmtDateOnly(dateTo!),
                                      icon: Icons.event_rounded,
                                      active: dateTo != null,
                                      onTap: () => _pickDate(from: false),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: _primaryButton(
                                      label: 'Terapkan',
                                      icon: Icons.filter_alt_rounded,
                                      onTap: _apply,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ghostButton(
                                      label: 'Reset',
                                      onTap: _reset,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== LIST =====
                      if (reports.isEmpty)
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: _r),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _blue.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(Icons.info_outline_rounded, color: _blue),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Tidak ada report pada filter ini.',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
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

                          final userObj = rr['user'];
                          String salesName = 'Sales';
                          if (userObj is Map) {
                            final u = userObj.cast<String, dynamic>();
                            salesName = (u['name'] ?? u['email'] ?? 'Sales').toString();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: _r,
                              onTap: id <= 0
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => ReportDetailPage(reportId: id)),
                                      ),
                              child: Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: _r),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: _blue.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: Icon(Icons.place_rounded, color: _blue),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.04),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    salesName,
                                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    time,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.black.withOpacity(0.55),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.chevron_right_rounded),
                                      ),
                                    ],
                                  ),
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
