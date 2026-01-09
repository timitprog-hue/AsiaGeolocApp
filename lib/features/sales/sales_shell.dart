import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../auth/login_page.dart';
import '../reports/report_create_page.dart';
import '../reports/report_detail_page.dart';
import '../reports/report_list_page.dart';

class SalesShell extends StatefulWidget {
  const SalesShell({super.key});

  @override
  State<SalesShell> createState() => _SalesShellState();
}

class _SalesShellState extends State<SalesShell> {
  // ===== STYLE (Blue Modern) =====
  static const Color _blue = Color(0xFF1D4ED8);
  static const Color _bg = Color(0xFFF6F8FF);

  int idx = 0;

  Future<void> _goCreateReport() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReportCreatePage()),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report berhasil dikirim')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      SalesHomePage(
        onOpenReportsTab: () => setState(() => idx = 1),
        onOpenCreate: _goCreateReport,
      ),
      const ReportListPage(),
      const SalesProfilePage(),
    ];

    final title = idx == 0 ? 'Home' : idx == 1 ? 'Reports' : 'Profile';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: pages[idx],

      // ✅ FAB tetap ada di semua halaman (Home/Reports/Profile)
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        onPressed: _goCreateReport,
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
  final VoidCallback onOpenReportsTab;
  final VoidCallback onOpenCreate;

  const SalesHomePage({
    super.key,
    required this.onOpenReportsTab,
    required this.onOpenCreate,
  });

  @override
  State<SalesHomePage> createState() => _SalesHomePageState();
}

class _SalesHomePageState extends State<SalesHomePage> {
  // ===== STYLE (Blue Modern) =====
  static const Color _blue = Color(0xFF1D4ED8);
  final BorderRadius _r = BorderRadius.circular(22);

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

  Future<void> _load() async {
    if (!mounted) return;
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
        final dt = _parseDate(raw);
        if (dt == null) continue;

        if (_isSameDay(dt, now)) t++;
        if (dt.isAfter(start7)) w++;

        if (latestTime == null || dt.isAfter(latestTime)) {
          latestTime = dt;
          latest = r;
        }
      }

      if (!mounted) return;
      setState(() {
        todayCount = t;
        weekCount = w;
        lastReport = latest;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          children: [
            // ===== HERO =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: _r,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _blue.withOpacity(0.95),
                    const Color(0xFF2563EB).withOpacity(0.88),
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktivitas Sales',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Kirim report dengan foto & lokasi yang akurat.',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: _r),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onOpenReportsTab,
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('Lihat Reports'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: widget.onOpenCreate,
                          icon: const Icon(Icons.add_a_photo_rounded),
                          label: const Text('Buat Report'),
                        ),
                      ),
                    ],
                  ),
                ),
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

class SalesProfilePage extends StatefulWidget {
  const SalesProfilePage({super.key});

  @override
  State<SalesProfilePage> createState() => _SalesProfilePageState();
}

class _SalesProfilePageState extends State<SalesProfilePage> {
  // ===== STYLE =====
  static const Color _blue = Color(0xFF1D4ED8);
  static const Color _bg = Color(0xFFF6F8FF);
  final BorderRadius _r = BorderRadius.circular(22);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = AuthStorage();
      final api = ApiClient(storage);

      final res = await api.dio.get('/me');
      if (res.data is! Map) throw Exception('Response /me bukan Map');

      if (!mounted) return;
      setState(() => _me = (res.data as Map).cast<String, dynamic>());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat profile.\n$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final storage = AuthStorage();
    final api = ApiClient(storage);

    try {
      await api.dio.post('/logout');
    } catch (_) {}

    await storage.clearToken();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final name = (_me?['name'] ?? 'Sales').toString();
    final email = (_me?['email'] ?? '-').toString();
    final role = (_me?['role'] ?? 'sales').toString();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          children: [
            // ===== HEADER / HERO =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: _r,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _blue.withOpacity(0.95),
                    const Color(0xFF2563EB).withOpacity(0.88),
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
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        _RoleChipBlue(role: role),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (_loading) ...[
              _ProfileSkeleton(bg: _bg),
            ] else if (_error != null) ...[
              _ProfileErrorCard(message: _error!, onRetry: _load),
            ] else ...[
              // ===== ACCOUNT DETAILS =====
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: _r),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Account', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      _InfoRow(label: 'Name', value: name),
                      _InfoRow(label: 'Email', value: email),
                      _InfoRow(label: 'Role', value: role),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ===== ACTIONS =====
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: _r),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.refresh_rounded, color: cs.primary),
                      title: const Text('Refresh data', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Ambil ulang data akun dari server'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _load,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.logout_rounded, color: cs.error),
                      title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Keluar dari akun sales'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleChipBlue extends StatelessWidget {
  final String role;
  const _RoleChipBlue({required this.role});

  @override
  Widget build(BuildContext context) {
    final text = role.trim().isEmpty ? '-' : role.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(label, style: TextStyle(color: sub, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ProfileErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 44),
            const SizedBox(height: 10),
            const Text('Gagal memuat profile', style: TextStyle(fontWeight: FontWeight.w900)),
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

class _ProfileSkeleton extends StatelessWidget {
  final Color bg;
  const _ProfileSkeleton({required this.bg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget box(double h) => Container(
          height: h,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
        );

    return Column(
      children: [
        box(140),
        const SizedBox(height: 12),
        box(160),
        const SizedBox(height: 12),
        box(170),
      ],
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
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75),
                      ),
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
