import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../auth/login_page.dart';
import 'report_create_page.dart';
import 'report_detail_page.dart';
import '../../core/auth_image.dart';
import '../../core/api_parser.dart';


class ReportListPage extends StatefulWidget {
  const ReportListPage({super.key});

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  bool _loading = true;
  List<dynamic> _items = [];
  String? _error;

  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = AuthStorage();
      final api = ApiClient(storage);

      _baseUrl ??= api.dio.options.baseUrl;

      final res = await api.dio.get('/reports');
      final data = ApiParser.extractList(res.data);
      setState(() => _items = data);

    } catch (e) {
      setState(() => _error = 'Gagal memuat laporan.\n$e');
    } finally {
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

  String _fmtDate(dynamic v) {
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return DateFormat("dd MMM yyyy • HH:mm").format(dt);
    } catch (_) {
      return v?.toString() ?? '-';
    }
  }

  String _stripApi(String baseUrl) {
    return baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  }

  String? _resolvePhotoUrl(dynamic report) {
    try {
      final photos = (report['photos'] as List<dynamic>?) ?? [];
      if (photos.isEmpty) return null;

      final p0 = photos[0];
      if (p0 is! Map) return null;

      final fileUrl = p0['file_url']?.toString();
      if (fileUrl != null && fileUrl.trim().isNotEmpty) {
        return fileUrl.trim();
      }

      final filePath = p0['file_path']?.toString();
      if (filePath == null || filePath.trim().isEmpty) return null;

      final base = _baseUrl;
      if (base == null || base.trim().isEmpty) return null;

      final origin = _stripApi(base.trim());
      return '$origin/storage/${filePath.trim()}';
    } catch (_) {
      return null;
    }
  }

  String _cacheBust(String url) {
    final u = Uri.parse(url);
    final qp = Map<String, String>.from(u.queryParameters);
    qp['v'] = DateTime.now().millisecondsSinceEpoch.toString();
    return u.replace(queryParameters: qp).toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const ReportCreatePage()),
          );
          if (ok == true) _load();
        },
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? _EmptyState(onCreate: () async {
                            final ok = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(builder: (_) => const ReportCreatePage()),
                            );
                            if (ok == true) _load();
                          })
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final r = _items[i];

                              final rawUrl = _resolvePhotoUrl(r);
                              final url = rawUrl == null ? null : _cacheBust(rawUrl);

                              final capturedAt = _fmtDate(r['captured_at']);

                              final address = (r['address']?.toString().trim().isNotEmpty == true)
                                  ? r['address'].toString()
                                  : 'Alamat belum tersedia';

                              final lat = r['latitude']?.toString() ?? '-';
                              final lng = r['longitude']?.toString() ?? '-';
                              final notes = r['notes']?.toString().trim() ?? '';

                              return Material(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    final id = r['id'];
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ReportDetailPage(reportId: id),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // HERO IMAGE (biar transisi ke detail lebih “wow”)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                        child: Container(
                                          height: 210,
                                          width: double.infinity,
                                          color: cs.surfaceContainerHighest,
                                          child: url == null
                                              ? const Center(child: Icon(Icons.image_not_supported_rounded))
                                              : AuthImage(url: url),
                                        ),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    capturedAt,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                const Icon(Icons.chevron_right_rounded),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.location_on_outlined, size: 18, color: cs.primary),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        address,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Koordinat: $lat, $lng',
                                                        style: TextStyle(
                                                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),

                                            if (notes.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: cs.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  notes,
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 120),
      children: [
        Icon(Icons.receipt_long_rounded, size: 56, color: cs.primary),
        const SizedBox(height: 12),
        const Text(
          'Belum ada report',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 6),
        Text(
          'Tekan tombol Tambah untuk mengirim report pertama kamu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75)),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_a_photo_rounded),
            label: const Text('Buat Report'),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 44, color: cs.error),
                const SizedBox(height: 10),
                const Text(
                  'Terjadi masalah',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
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
        ),
      ),
    );
  }
}
