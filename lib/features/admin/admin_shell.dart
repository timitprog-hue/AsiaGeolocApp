import 'package:flutter/material.dart';

import 'admin_map_page.dart';
import 'admin_reports_page.dart';
import 'admin_users_page.dart';
import 'admin_profile_page.dart';

// plus yang lain kalau masih kamu pakai:
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/api_parser.dart';
import '../reports/report_detail_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AdminDashboardPage(),
      const AdminReportsPage(),
      const AdminMapPage(),
      const AdminUsersPage(),
    ];

    final titles = <String>['Dashboard', 'Reports', 'Map', 'Users'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[idx]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PremiumProfileButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminProfilePage()),
                );
              },
            ),
          ),
        ],
      ),
      body: pages[idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (v) => setState(() => idx = v),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Users'),
        ],
      ),
    );
  }
}

class _PremiumProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withOpacity(0.10),
            border: Border.all(
              color: cs.onSurface.withOpacity(0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface,
                border: Border.all(
                  color: cs.primary.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: cs.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

enum _Range { today, d7, d30 }

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;

  _Range range = _Range.today;

  int kpiTotal = 0;
  int kpiToday = 0;
  Map<String, dynamic>? lastReport;
  List<Map<String, dynamic>> recent = [];
  List<_Bucket> buckets = [];

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  String _fmtDate(dynamic v) {
    final dt = _parseDate(v);
    if (dt == null) return v?.toString() ?? '-';
    return DateFormat("dd MMM yyyy • HH:mm").format(dt);
  }

  DateTime _startForRange(_Range r, DateTime now) {
    switch (r) {
      case _Range.today:
        return DateTime(now.year, now.month, now.day);
      case _Range.d7:
        return now.subtract(const Duration(days: 7));
      case _Range.d30:
        return now.subtract(const Duration(days: 30));
    }
  }

  String _rangeLabel(_Range r) {
    switch (r) {
      case _Range.today:
        return 'Today';
      case _Range.d7:
        return '7 Days';
      case _Range.d30:
        return '30 Days';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = AuthStorage();
      final api = ApiClient(storage);

      final res = await api.dio.get('/reports');
      final data = ApiParser.extractList(res.data);

      final now = DateTime.now();
      final start = _startForRange(range, now);

      int totalInRange = 0;
      int totalToday = 0;

      DateTime? latestTime;
      Map<String, dynamic>? latest;

      final List<Map<String, dynamic>> rec = [];
      final Map<String, int> byDay = {}; // yyyy-MM-dd -> count

      for (final item in data) {
        if (item is! Map) continue;
        final r = item.cast<String, dynamic>();

        final dt = _parseDate(r['captured_at'] ?? r['created_at']);
        if (dt == null) continue;

        if (_isSameDay(dt, now)) totalToday++;

        if (!dt.isBefore(start)) {
          totalInRange++;
          final key = DateFormat('yyyy-MM-dd').format(dt);
          byDay[key] = (byDay[key] ?? 0) + 1;
        }

        if (latestTime == null || dt.isAfter(latestTime)) {
          latestTime = dt;
          latest = r;
        }

        rec.add(r);
      }

      // ✅ sort recent by captured_at desc
      rec.sort((a, b) {
        final da = _parseDate(a['captured_at'] ?? a['created_at']) ?? DateTime(1970);
        final db = _parseDate(b['captured_at'] ?? b['created_at']) ?? DateTime(1970);
        return db.compareTo(da);
      });

      final top = rec.take(5).toList();
      final built = _buildBuckets(range, now, byDay);

      setState(() {
        kpiTotal = totalInRange;
        kpiToday = totalToday;
        lastReport = latest;
        recent = top;
        buckets = built;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat dashboard.\n$e';
        _loading = false;
      });
    }
  }

  List<_Bucket> _buildBuckets(_Range r, DateTime now, Map<String, int> byDay) {
    if (r == _Range.today) {
      final key = DateFormat('yyyy-MM-dd').format(now);
      return [_Bucket(label: 'Today', value: byDay[key] ?? 0)];
    }

    if (r == _Range.d7) {
      final list = <_Bucket>[];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(d);
        final label = DateFormat('E').format(d);
        list.add(_Bucket(label: label, value: byDay[key] ?? 0));
      }
      return list;
    }

    final list = <_Bucket>[];
    for (int g = 9; g >= 0; g--) {
      final end = now.subtract(Duration(days: g * 3));
      final start = end.subtract(const Duration(days: 2));
      int sum = 0;
      for (int i = 0; i < 3; i++) {
        final d = start.add(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(d);
        sum += byDay[key] ?? 0;
      }
      final label =
          '${DateFormat('d').format(start)}-${DateFormat('d').format(end)}';
      list.add(_Bucket(label: label, value: sum));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.admin_panel_settings_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Dashboard',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Monitoring laporan sales'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<_Range>(
                segments: const [
                  ButtonSegment(value: _Range.today, label: Text('Today')),
                  ButtonSegment(value: _Range.d7, label: Text('Week')),
                  ButtonSegment(value: _Range.d30, label: Text('Month')),
                ],
                selected: {range},
                onSelectionChanged: (s) {
                  final next = s.first;
                  if (next == range) return;
                  setState(() => range = next);
                  _load();
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (_loading) ...[
            _AdminSkeleton(cs: cs),
          ] else if (_error != null) ...[
            _AdminErrorCard(message: _error!, onRetry: _load),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _AdminKpiCard(
                    title: 'Total (${_rangeLabel(range)})',
                    value: kpiTotal.toString(),
                    icon: Icons.analytics_rounded,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdminKpiCard(
                    title: 'Hari ini',
                    value: kpiToday.toString(),
                    icon: Icons.today_rounded,
                    color: cs.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trend (${_rangeLabel(range)})',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    _MiniBarChart(buckets: buckets),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            _AdminLastReportCard(
              report: lastReport,
              fmtDate: _fmtDate,
              asInt: _asInt,
              onOpen: (id) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReportDetailPage(reportId: id)),
              ),
            ),

            const SizedBox(height: 12),

            const Text('Recent Reports', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),

            if (recent.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline_rounded),
                      SizedBox(width: 10),
                      Expanded(child: Text('Belum ada report masuk.')),
                    ],
                  ),
                ),
              )
            else
              ...recent.map((r) {
                final id = _asInt(r['id']);
                final address = (r['address']?.toString().trim().isNotEmpty == true)
                    ? r['address'].toString()
                    : 'Alamat belum tersedia';
                final time = _fmtDate(r['captured_at'] ?? r['created_at']);

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
                      subtitle: Text(time),
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
        ],
      ),
    );
  }
}

// ===== Mini chart (no libs) =====
class _Bucket {
  final String label;
  final int value;
  _Bucket({required this.label, required this.value});
}

class _MiniBarChart extends StatelessWidget {
  final List<_Bucket> buckets;
  const _MiniBarChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (buckets.isEmpty) {
      return Text(
        'Tidak ada data.',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75),
        ),
      );
    }

    final maxVal = buckets.map((b) => b.value).fold<int>(1, (p, v) => v > p ? v : p);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: buckets.map((b) {
        final h = (b.value / maxVal) * 80.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${b.value}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  height: 90,
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: h.isNaN ? 0 : h,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  b.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ===== KPI widgets =====
class _AdminKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AdminKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: cs.onSurface.withOpacity(0.65))),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminLastReportCard extends StatelessWidget {
  final Map<String, dynamic>? report;
  final String Function(dynamic v) fmtDate;
  final int Function(dynamic v) asInt;
  final void Function(int id) onOpen;

  const _AdminLastReportCard({
    required this.report,
    required this.fmtDate,
    required this.asInt,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (report == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: cs.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Belum ada report yang masuk.', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    final id = asInt(report!['id']);
    final address = (report!['address']?.toString().trim().isNotEmpty == true)
        ? report!['address'].toString()
        : 'Alamat belum tersedia';
    final time = fmtDate(report!['captured_at'] ?? report!['created_at']);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: id > 0 ? () => onOpen(id) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.history_rounded, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report terakhir', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _AdminErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 42),
            const SizedBox(height: 10),
            const Text('Gagal memuat', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSkeleton extends StatelessWidget {
  final ColorScheme cs;
  const _AdminSkeleton({required this.cs});

  @override
  Widget build(BuildContext context) {
    Widget box(double h) => Container(
          height: h,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
        );

    return Column(
      children: [
        box(70),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: box(82)),
            const SizedBox(width: 12),
            Expanded(child: box(82)),
          ],
        ),
        const SizedBox(height: 12),
        box(140),
        const SizedBox(height: 12),
        box(92),
      ],
    );
  }
}
