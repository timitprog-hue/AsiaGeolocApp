import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../auth/login_page.dart';
import '../reports/report_create_page.dart';
import '../reports/report_detail_page.dart';
import '../reports/report_list_page.dart';
import '../../core/live_location_service.dart';


class SalesShell extends StatefulWidget {
  const SalesShell({super.key});

  @override
  State<SalesShell> createState() => _SalesShellState();
}

class _SalesShellState extends State<SalesShell> {
  int idx = 0;

  final _live = LiveLocationService();

  @override
  void initState() {
    super.initState();
    // ✅ mulai kirim lokasi berkala (boleh 10 detik dulu biar kerasa live)
    _live.start(interval: const Duration(seconds: 10));
  }

  @override
  void dispose() {
    _live.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const SalesHomePage(),
      const ReportListPage(),
      const SalesProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(idx == 0 ? 'Home' : idx == 1 ? 'Reports' : 'Profile'),
      ),
      body: pages[idx],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ReportCreatePage()),
          );
          if (ok == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report berhasil dikirim')),
            );
          }
        },
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Buat Report'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (v) => setState(() => idx = v),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}


class SalesHomePage extends StatefulWidget {
  const SalesHomePage({super.key});

  @override
  State<SalesHomePage> createState() => _SalesHomePageState();
}

class _SalesHomePageState extends State<SalesHomePage> {
  bool _loading = true;
  String? _error;

  int todayCount = 0;
  int weekCount = 0;
  Map<String, dynamic>? lastReport;

  String _fmtDate(dynamic v) {
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return DateFormat("dd MMM yyyy • HH:mm").format(dt);
    } catch (_) {
      return v?.toString() ?? '-';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = AuthStorage();
      final api = ApiClient(storage);

      final res = await api.dio.get('/reports');
      final data = (res.data['data'] as List<dynamic>?) ?? [];

      final now = DateTime.now();
      final start7 = now.subtract(const Duration(days: 7));

      int t = 0;
      int w = 0;

      Map<String, dynamic>? latest;
      DateTime? latestTime;

      for (final item in data) {
        if (item is! Map) continue;
        final r = item.cast<String, dynamic>();

        final raw = r['captured_at'] ?? r['created_at'] ?? r['waktu'];
        if (raw == null) continue;

        DateTime? dt;
        try {
          // captured_at biasanya ISO
          dt = DateTime.parse(raw.toString()).toLocal();
        } catch (_) {
          // fallback kalau format SQL "yyyy-MM-dd HH:mm:ss"
          try {
            dt = DateFormat("yyyy-MM-dd HH:mm:ss").parse(raw.toString());
          } catch (_) {
            dt = null;
          }
        }
        if (dt == null) continue;

        if (_isSameDay(dt, now)) t++;
        if (dt.isAfter(start7)) w++;

        if (latestTime == null || dt.isAfter(latestTime)) {
          latestTime = dt;
          latest = r;
        }
      }

      setState(() {
        todayCount = t;
        weekCount = w;
        lastReport = latest;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data.\n$e';
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            _HeaderCard(
              title: 'Aktivitas Sales',
              subtitle: 'Pastikan report dikirim dengan foto & lokasi yang akurat.',
              icon: Icons.location_on_rounded,
            ),
            const SizedBox(height: 12),

            if (_loading) ...[
              const _KpiSkeleton(),
            ] else if (_error != null) ...[
              _ErrorCard(message: _error!, onRetry: _load),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      title: 'Hari ini',
                      value: todayCount.toString(),
                      icon: Icons.today_rounded,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      title: '7 hari',
                      value: weekCount.toString(),
                      icon: Icons.bar_chart_rounded,
                      color: cs.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _QuickActions(
                onCreate: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportCreatePage()),
                  );
                  if (ok == true) _load();
                },
                onOpenReports: () {
                  // kalau kamu ingin pindah ke tab Reports: nanti kita buat callback dari shell
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportListPage()));
                },
              ),

              const SizedBox(height: 12),

              _LastReportCard(
                report: lastReport,
                fmtDate: _fmtDate,
                onOpen: (id) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportDetailPage(reportId: id)),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SalesProfilePage extends StatelessWidget {
  const SalesProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final storage = AuthStorage();
    final api = ApiClient(storage);

    try {
      await api.dio.post('/logout');
    } catch (_) {}

    await storage.clearToken();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        const _HeaderCard(
          title: 'Akun',
          subtitle: 'Kelola akun dan keamanan aplikasi.',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_rounded),
            title: const Text('Ganti Password'),
            subtitle: const Text('Coming soon'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur ganti password menyusul 👍')),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Logout'),
            onTap: () => _logout(context),
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
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

class _QuickActions extends StatelessWidget {
  final VoidCallback onOpenReports;
  final VoidCallback onCreate;

  const _QuickActions({required this.onOpenReports, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenReports,
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Lihat Reports'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('Buat Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastReportCard extends StatelessWidget {
  final Map<String, dynamic>? report;
  final String Function(dynamic v) fmtDate;
  final void Function(int id) onOpen;

  const _LastReportCard({
    required this.report,
    required this.fmtDate,
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
                child: Text(
                  'Belum ada report. Tekan "Buat Report" untuk mulai.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final id = int.tryParse(report!['id'].toString()) ?? 0;
    final address = (report!['address']?.toString().trim().isNotEmpty == true)
        ? report!['address'].toString()
        : 'Alamat belum tersedia';

    final capturedAt = fmtDate(report!['captured_at'] ?? report!['created_at']);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: id == 0 ? null : () => onOpen(id),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      capturedAt,
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

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

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget box({double h = 82}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: box()),
            const SizedBox(width: 12),
            Expanded(child: box()),
          ],
        ),
        const SizedBox(height: 12),
        box(h: 74),
        const SizedBox(height: 12),
        box(h: 92),
      ],
    );
  }
}