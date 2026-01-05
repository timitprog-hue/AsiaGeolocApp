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
      setState(() => _error = 'Gagal load detail: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _stripApi(String baseUrl) {
    // http://ip:8000/api -> http://ip:8000
    return baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  }

  bool _looksLikeApiPhotoUrl(String url) {
    // contoh: http://ip:8000/api/photos/20
    return url.contains('/api/photos/');
  }

  String? _resolvePhotoUrl(Map<String, dynamic> report) {
    final photos = (report['photos'] as List?) ?? [];
    if (photos.isEmpty) return null;

    final p0 = (photos.first as Map).cast<String, dynamic>();

    final base = _baseUrl;
    if (base == null || base.trim().isEmpty) return null;
    final origin = _stripApi(base.trim());

    // Ambil file_path untuk fallback /storage
    final filePath = p0['file_path']?.toString().trim();
    final storageUrl = (filePath != null && filePath.isNotEmpty)
        ? '$origin/storage/$filePath'
        : null;

    // 1) kalau file_url ada tapi ternyata /api/photos/xxx -> PAKAI storageUrl
    final fileUrl = p0['file_url']?.toString().trim();
    if (fileUrl != null && fileUrl.isNotEmpty) {
      if (_looksLikeApiPhotoUrl(fileUrl)) {
        return storageUrl ?? fileUrl;
      }
      return fileUrl;
    }

    // 2) fallback dari file_path
    return storageUrl;
  }

  String _fmtDate(dynamic v) {
    try {
      final dt = DateTime.parse(v.toString()).toLocal(); // biar konsisten lokal
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
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : r == null
                  ? const Center(child: Text('Data kosong'))
                  : _buildContent(r),
    );
  }

  Widget _buildContent(Map<String, dynamic> r) {
    String? url = _resolvePhotoUrl(r);

    // cache buster
    if (url != null && url.isNotEmpty) {
      final v = DateTime.now().millisecondsSinceEpoch;
      url = url.contains('?') ? '$url&v=$v' : '$url?v=$v';
    }

    debugPrint('DETAIL PHOTO URL: $url');

    final capturedAt = _fmtDate(r['captured_at']);
    final address = (r['address']?.toString().trim().isNotEmpty == true)
        ? r['address'].toString()
        : 'Alamat belum tersedia';

    final lat = r['latitude']?.toString() ?? '-';
    final lng = r['longitude']?.toString() ?? '-';
    final acc = r['accuracy_m']?.toString() ?? '-';
    final notes = r['notes']?.toString().trim() ?? '';

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 260,
            color: const Color(0xFFE6E6E6),
            child: url == null
                ? const Center(child: Icon(Icons.image_not_supported, size: 40))
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (_, e, __) {
                      debugPrint('DETAIL IMG ERROR: $e\nURL: $url');
                      return const Center(child: Icon(Icons.broken_image, size: 40));
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(capturedAt, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(address, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          'Koordinat: $lat, $lng • Akurasi: $acc m',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Catatan', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(notes),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
