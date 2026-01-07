import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';

class ReportDetailPage extends StatefulWidget {
  final int reportId;
  const ReportDetailPage({super.key, required this.reportId});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;

  String? _baseUrl; // http://ip:8000/api

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

      final res = await api.dio.get('/reports/${widget.reportId}');
      final data = (res.data as Map?)?.cast<String, dynamic>();
      if (data == null) throw Exception('Data report kosong');

      setState(() => _report = data);
    } catch (e) {
      setState(() => _error = 'Gagal memuat detail.\n$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _stripApi(String baseUrl) => baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  bool _looksLikeApiPhotoUrl(String url) => url.contains('/api/photos/');

  String? _resolvePhotoUrl(Map<String, dynamic> report) {
    final photos = (report['photos'] as List?) ?? [];
    if (photos.isEmpty) return null;

    final p0 = (photos.first as Map).cast<String, dynamic>();

    final base = _baseUrl;
    if (base == null || base.trim().isEmpty) return null;
    final origin = _stripApi(base.trim());

    final filePath = p0['file_path']?.toString().trim();
    final storageUrl = (filePath != null && filePath.isNotEmpty) ? '$origin/storage/$filePath' : null;

    final fileUrl = p0['file_url']?.toString().trim();
    if (fileUrl != null && fileUrl.isNotEmpty) {
      if (_looksLikeApiPhotoUrl(fileUrl)) return storageUrl ?? fileUrl;
      return fileUrl;
    }

    return storageUrl;
  }

  String _fmtDate(dynamic v) {
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return DateFormat("dd MMM yyyy • HH:mm").format(dt);
    } catch (_) {
      return v?.toString() ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Report'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _DetailError(message: _error!, onRetry: _load)
                : r == null
                    ? const Center(child: Text('Data kosong'))
                    : _buildContent(r),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> r) {
    final cs = Theme.of(context).colorScheme;

    String? url = _resolvePhotoUrl(r);
    if (url != null && url.isNotEmpty) {
      final v = DateTime.now().millisecondsSinceEpoch;
      url = url.contains('?') ? '$url&v=$v' : '$url?v=$v';
    }

    final capturedAt = _fmtDate(r['captured_at']);
    final address = (r['address']?.toString().trim().isNotEmpty == true)
        ? r['address'].toString()
        : 'Alamat belum tersedia';

    final lat = r['latitude']?.toString() ?? '-';
    final lng = r['longitude']?.toString() ?? '-';
    final acc = r['accuracy_m']?.toString() ?? '-';
    final notes = r['notes']?.toString().trim() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 280,
            color: cs.surfaceContainerHighest,
            child: url == null
                ? const Center(child: Icon(Icons.image_not_supported_rounded, size: 42))
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (_, __, ___) {
                      return const Center(child: Icon(Icons.broken_image_rounded, size: 42));
                    },
                  ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capturedAt,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(address, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            'Koordinat: $lat, $lng • Akurasi: $acc m',
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Catatan', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(notes),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _DetailError({required this.message, required this.onRetry});

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
        ),
      ),
    );
  }
}
