import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../auth/login_page.dart';
import 'report_create_page.dart';
import 'report_detail_page.dart';
import '../../core/auth_image.dart';


class ReportListPage extends StatefulWidget {
  const ReportListPage({super.key});

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  bool _loading = true;
  List<dynamic> _items = [];
  String? _error;

  // simpan baseUrl dari ApiClient biar bisa fallback dari file_path
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
      final data = (res.data['data'] as List<dynamic>?) ?? [];
      setState(() => _items = data);
    } catch (e) {
      setState(() => _error = 'Gagal load: $e');
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
    final dt = DateTime.parse(v.toString()).toLocal(); // WAJIB
    return DateFormat("dd MMM yyyy • HH:mm").format(dt);
  } catch (_) {
    return v?.toString() ?? '-';
  }
}


  String _stripApi(String baseUrl) {
    // http://ip:8000/api  -> http://ip:8000
    return baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  }

  String? _resolvePhotoUrl(dynamic report) {
    try {
      final photos = (report['photos'] as List<dynamic>?) ?? [];
      if (photos.isEmpty) return null;

      final p0 = photos[0];
      if (p0 is! Map) return null;

      // 1) prioritas file_url
      final fileUrl = p0['file_url']?.toString();
      if (fileUrl != null && fileUrl.trim().isNotEmpty) {
        return fileUrl.trim();
      }

      // 2) fallback dari file_path
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

  /// Cache-busting biar gambar nggak “ngilang” / nyangkut cache
  String _cacheBust(String url) {
    final u = Uri.parse(url);
    final qp = Map<String, String>.from(u.queryParameters);
    qp['v'] = DateTime.now().millisecondsSinceEpoch.toString();
    return u.replace(queryParameters: qp).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const ReportCreatePage()),
          );
          if (ok == true) _load();
        },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Tambah'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final r = _items[i];

                      final rawUrl = _resolvePhotoUrl(r);
                      final url = rawUrl == null ? null : _cacheBust(rawUrl);

                      final capturedAt = _fmtDate(r['captured_at']);

                      // ✅ alamat tetap pakai field DB: address (yang sudah aman di kamu)
                      final address = (r['address']?.toString().trim().isNotEmpty == true)
                          ? r['address'].toString()
                          : 'Alamat belum tersedia';

                      final lat = r['latitude']?.toString() ?? '-';
                      final lng = r['longitude']?.toString() ?? '-';
                      final notes = r['notes']?.toString() ?? '';

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          final id = r['id'];
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportDetailPage(reportId: id),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // IMAGE
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                child: Container(
                                  height: 220,
                                  width: double.infinity,
                                  color: const Color(0xFFE6E6E6),
                                  child: url == null
                                      ? const Center(child: Icon(Icons.image_not_supported))
                                      : AuthImage(url: url),
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      capturedAt,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                address,
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Koordinat: $lat, $lng',
                                                style: const TextStyle(color: Colors.black54),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.chevron_right, color: Colors.black38),
                                      ],
                                    ),
                                    if (notes.trim().isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(notes, style: const TextStyle(fontWeight: FontWeight.w600)),
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
    );
  }
}
