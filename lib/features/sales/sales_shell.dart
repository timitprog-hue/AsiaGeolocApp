import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/live_location_service.dart';

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
  // ✅ Tema sama Admin
  static const Color _bg = Color(0xFFF6F8FF);
  static const Color _blue = Color(0xFF1D4ED8);
  static const Color _blue2 = Color(0xFF2563EB);
  static const Color _blue3 = Color(0xFF60A5FA);

  int idx = 0;
  final _live = LiveLocationService();

  // ✅ supaya bisa panggil reload Home & Reports dari Shell
  final GlobalKey<_SalesHomePageState> _homeKey = GlobalKey<_SalesHomePageState>();
  final GlobalKey<ReportListPageState> _reportsKey = GlobalKey<ReportListPageState>();

  @override
  void initState() {
    super.initState();
    _live.start(interval: const Duration(seconds: 10));
  }

  @override
  void dispose() {
    _live.stop();
    super.dispose();
  }

  Future<void> _openCreateReport() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReportCreatePage()),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report berhasil dikirim')),
      );

      // ✅ refresh halaman aktif biar data langsung update
      if (idx == 0) {
        _homeKey.currentState?.reload();
      } else if (idx == 1) {
        _reportsKey.currentState?.reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    final cs = ColorScheme.fromSeed(
      seedColor: _blue,
      brightness: base.brightness,
      primary: _blue,
    );

    final theme = base.copyWith(
      colorScheme: cs,
      useMaterial3: true,
      scaffoldBackgroundColor: base.brightness == Brightness.dark
          ? const Color(0xFF0B1220)
          : _bg,
      cardTheme: CardThemeData(
        elevation: 0,
        color: base.brightness == Brightness.dark ? const Color(0xFF101A2D) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: base.brightness == Brightness.dark ? const Color(0xFF0B1220) : _bg,
        foregroundColor: base.brightness == Brightness.dark ? Colors.white : Colors.black87,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: base.brightness == Brightness.dark ? Colors.white : Colors.black87,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: base.brightness == Brightness.dark ? const Color(0xFF0E1730) : Colors.white,
        selectedItemColor: _blue,
        unselectedItemColor: cs.onSurface.withOpacity(0.55),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    final pages = <Widget>[
      SalesHomePage(key: _homeKey),
      ReportListPage(key: _reportsKey),
      const SalesProfilePage(),
    ];

    final titles = ['Dashboard', 'Reports', 'Profile'];

    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: _bg,
            appBar: _SalesAppBar(title: titles[idx]),
            body: pages[idx],

            // ✅ FAB SELALU ADA DI SEMUA HALAMAN
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _openCreateReport,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Buat Report', style: TextStyle(fontWeight: FontWeight.w900)),
              backgroundColor: _blue,
              foregroundColor: Colors.white,
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

            bottomNavigationBar: BottomNavigationBar(
              currentIndex: idx,
              onTap: (v) => setState(() => idx = v),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Reports'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SalesAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _SalesAppBar({required this.title});

  static const Color _bg = Color(0xFFF6F8FF);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

/* =========================
   DASHBOARD (HOME)
========================= */

class SalesHomePage extends StatefulWidget {
  const SalesHomePage({super.key});

  @override
  State<SalesHomePage> createState() => _SalesHomePageState();
}

class _SalesHomePageState extends State<SalesHomePage> {
  // ✅ Tema sama Admin
  static const Color _bg = Color(0xFFF6F8FF);
  static const Color _blue = Color(0xFF1D4ED8);
  static const Color _blue2 = Color(0xFF2563EB);
  static const Color _blue3 = Color(0xFF60A5FA);
  final BorderRadius _r = BorderRadius.circular(22);

  bool _loading = true;
  String? _error;

  int todayCount = 0;
  int weekCount = 0;
  Map<String, dynamic>? lastReport;

  // ✅ dipanggil dari SalesShell setelah create report
  void reload() {
    _load();
  }

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
          dt = DateTime.parse(raw.toString()).toLocal();
        } catch (_) {
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

    return Container(
      color: _bg,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            // ✅ dinaikkan biar aman tidak ketutup FAB
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
            children: [
              // ===== HERO (tema Admin) =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: _r,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _blue.withOpacity(0.96),
                      _blue2.withOpacity(0.86),
                      _blue3.withOpacity(0.55),
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
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.22)),
                      ),
                      child: const Icon(Icons.assignment_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Aktivitas Sales',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total laporan hari ini: $todayCount',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w700,
                            ),
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
                _ErrorCard(message: _error!, onRetry: _load, radius: _r, blue: _blue),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Hari ini',
                        value: todayCount.toString(),
                        icon: Icons.today_rounded,
                        tint: _blue,
                        radius: _r,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: '7 hari',
                        value: weekCount.toString(),
                        icon: Icons.auto_graph_rounded,
                        tint: _blue2,
                        radius: _r,
                      ),
                    ),
                  ],
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
                  radius: _r,
                  blue: _blue,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   PROFILE
========================= */

class SalesProfilePage extends StatefulWidget {
  const SalesProfilePage({super.key});

  @override
  State<SalesProfilePage> createState() => _SalesProfilePageState();
}

class _SalesProfilePageState extends State<SalesProfilePage> {
  // ✅ Tema sama Admin
  static const Color _bg = Color(0xFFF6F8FF);
  static const Color _blue = Color(0xFF1D4ED8);
  static const Color _blue2 = Color(0xFF2563EB);
  static const Color _blue3 = Color(0xFF60A5FA);
  final BorderRadius _r = BorderRadius.circular(22);

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? me; // {name,email,role}

  Future<void> _loadMe() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = AuthStorage();
      final api = ApiClient(storage);

      dynamic res;
      try {
        res = await api.dio.get('/me');
      } catch (_) {
        res = await api.dio.get('/profile');
      }

      final data = (res.data is Map && res.data['data'] != null)
          ? (res.data['data'] as Map).cast<String, dynamic>()
          : (res.data as Map).cast<String, dynamic>();

      setState(() {
        me = {
          'name': data['name'] ?? data['nama'] ?? '-',
          'email': data['email'] ?? '-',
          'role': data['role'] ?? data['level'] ?? data['jabatan'] ?? '-',
        };
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal ambil data akun.\n$e';
        _loading = false;
      });
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
  void initState() {
    super.initState();
    _loadMe();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final name = (me?['name'] ?? '-') as String;
    final email = (me?['email'] ?? '-') as String;
    final role = (me?['role'] ?? '-') as String;

    return Container(
      color: _bg,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMe,
          child: ListView(
            // ✅ padding bawah dinaikkan biar aman tidak ketutup FAB
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
            children: [
              // ===== HERO (tema Admin) =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: _r,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _blue.withOpacity(0.96),
                      _blue2.withOpacity(0.86),
                      _blue3.withOpacity(0.55),
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
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.22)),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Akun Sales',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kelola akun, keamanan, dan sesi login.',
                            style: TextStyle(
                              color: Color(0xE6FFFFFF),
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

              const _SectionTitle(title: 'Account'),
              const SizedBox(height: 10),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: _r),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Name', value: _loading ? '...' : name),
                      const SizedBox(height: 10),
                      _InfoRow(label: 'Email', value: _loading ? '...' : email),
                      const SizedBox(height: 10),
                      _InfoRow(label: 'Role', value: _loading ? '...' : role),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.error.withOpacity(0.20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: cs.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const _SectionTitle(title: 'Actions'),
              const SizedBox(height: 10),

              _ModernTile(
                icon: Icons.refresh_rounded,
                title: 'Refresh data',
                subtitle: 'Ambil ulang data akun dari server',
                onTap: _loadMe,
                blue: _blue,
              ),
              const SizedBox(height: 10),

              _ModernTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Keluar dari akun',
                destructive: true,
                onTap: _logout,
                blue: _blue,
              ),
            ],
          ),
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
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

/* =========================
   PROFILE COMPONENTS
========================= */

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w900,
        color: cs.onSurface.withOpacity(0.55),
      ),
    );
  }
}

class _ModernTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final Color blue;

  const _ModernTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.blue,
    this.subtitle,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = destructive ? cs.error : blue;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: destructive ? cs.error : cs.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.70),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurface.withOpacity(0.55)),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   SHARED WIDGETS
========================= */

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final BorderRadius radius;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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
  final BorderRadius radius;
  final Color blue;

  const _LastReportCard({
    required this.report,
    required this.fmtDate,
    required this.onOpen,
    required this.radius,
    required this.blue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (report == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: blue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Belum ada report. Tekan "Buat Report" untuk mulai.',
                  style: TextStyle(fontWeight: FontWeight.w800),
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
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        borderRadius: radius,
        onTap: id == 0 ? null : () => onOpen(id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.history_rounded, color: blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report terakhir', style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface)),
                    const SizedBox(height: 6),
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, height: 1.15),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: cs.onSurface.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            capturedAt,
                            style: TextStyle(color: cs.onSurface.withOpacity(0.70), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurface.withOpacity(0.55)),
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
  final BorderRadius radius;
  final Color blue;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.radius,
    required this.blue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius),
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
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
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

    Widget box({double h = 86}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
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
        box(h: 78),
        const SizedBox(height: 12),
        box(h: 98),
      ],
    );
  }
}
