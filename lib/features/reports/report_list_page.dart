import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
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
  // ===== STYLE (Blue Modern) =====
  static const Color _blue = Color(0xFF1D4ED8);
  static const Color _bg = Color(0xFFF6F8FF);
  final BorderRadius _r = BorderRadius.circular(22);

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
    if (!mounted) return;
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

      if (!mounted) return;
      setState(() => _items = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat laporan.\n$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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

  Future<void> _goCreate() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReportCreatePage()),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
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
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Laporan Kamu',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: ${_items.length}',
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

                        if (_items.isEmpty)
                          _EmptyState(onCreate: _goCreate)
                        else
                          ..._items.map((r) {
                            final rawUrl = _resolvePhotoUrl(r);
                            final url = rawUrl == null ? null : _cacheBust(rawUrl);

                            final capturedAt = _fmtDate(r['captured_at'] ?? r['created_at']);

                            final address = (r['address']?.toString().trim().isNotEmpty == true)
                                ? r['address'].toString()
                                : 'Alamat belum tersedia';

                            final lat = r['latitude']?.toString() ?? '-';
                            final lng = r['longitude']?.toString() ?? '-';
                            final notes = r['notes']?.toString().trim() ?? '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: _r),
                                child: InkWell(
                                  borderRadius: _r,
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
                                      // ===== HERO IMAGE =====
                                      ClipRRect(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(_r.topLeft.x),
                                        ),
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
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: cs.onSurface.withOpacity(0.65),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.location_on_outlined, size: 18, color: _blue),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        address,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Koordinat: $lat, $lng',
                                                        style: TextStyle(
                                                          color: Theme.of(context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.color
                                                              ?.withOpacity(0.75),
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
                                                  borderRadius: BorderRadius.circular(14),
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
                              ),
                            );
                          }).toList(),
                      ],
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 22),
        child: Column(
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
              'Tekan tombol Buat untuk mengirim report pertama kamu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
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
