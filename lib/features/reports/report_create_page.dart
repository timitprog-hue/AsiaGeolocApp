import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/camera_capture_page.dart';

class ReportCreatePage extends StatefulWidget {
  const ReportCreatePage({super.key});

  @override
  State<ReportCreatePage> createState() => _ReportCreatePageState();
}

class _ReportCreatePageState extends State<ReportCreatePage> {
  bool _loading = false;
  String? _error;

  Position? _pos;
  String? _address;
  XFile? _photo;

  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      await _getLocation();
      await _reverseGeocode();
    } catch (e) {
      setState(() => _error = 'Lokasi gagal: $e');
    }
  }

  Future<void> _getLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('GPS/Location service mati');

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak');
    }

    final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() => _pos = p);
  }

  Future<void> _reverseGeocode() async {
    if (_pos == null) return;
    try {
      final placemarks = await placemarkFromCoordinates(_pos!.latitude, _pos!.longitude);
      if (placemarks.isEmpty) return;
      final pm = placemarks.first;

      final parts = <String>[
        if ((pm.street ?? '').isNotEmpty) pm.street!,
        if ((pm.subLocality ?? '').isNotEmpty) pm.subLocality!,
        if ((pm.locality ?? '').isNotEmpty) pm.locality!,
        if ((pm.administrativeArea ?? '').isNotEmpty) pm.administrativeArea!,
      ];

      setState(() => _address = parts.join(', '));
    } catch (_) {
      setState(() => _address = null);
    }
  }

  Future<File> _compress(File input) async {
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/cmp_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      outPath,
      quality: 70,
    );

    return result != null ? File(result.path) : input;
  }

  Future<void> _openCamera() async {
    final file = await Navigator.of(context).push<XFile?>(
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
    );
    if (file != null) {
      setState(() => _photo = file);
    }
  }

  Future<void> _refreshLocation() async {
    if (_loading) return;
    setState(() => _error = null);

    try {
      await _getLocation();
      await _reverseGeocode();
    } catch (e) {
      setState(() => _error = 'Lokasi gagal: $e');
    }
  }

  Future<void> _upload() async {
    if (_pos == null) {
      setState(() => _error = 'Lokasi belum ada. Coba refresh lokasi.');
      return;
    }
    if (_photo == null) {
      setState(() => _error = 'Foto belum diambil.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = AuthStorage();
      final api = ApiClient(storage);

      final rawFile = File(_photo!.path);
      final file = await _compress(rawFile);

      final now = DateTime.now();

      final form = FormData.fromMap({
        'photo': await MultipartFile.fromFile(file.path, filename: 'photo.jpg'),
        'latitude': _pos!.latitude,
        'longitude': _pos!.longitude,
        'accuracy_m': _pos!.accuracy,
        'captured_at': now.toIso8601String(),

        // backend pakai "address"
        'address': _address ?? '',
        'notes': _notesCtrl.text.trim(),
      });

      await api.dio.post('/reports', data: form);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Upload gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final nowStr = DateFormat("dd MMM yyyy • HH:mm").format(DateTime.now());

    final lat = _pos?.latitude.toStringAsFixed(6);
    final lng = _pos?.longitude.toStringAsFixed(6);
    final acc = _pos?.accuracy.toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Report'),
        actions: [
          IconButton(
            tooltip: 'Refresh lokasi',
            onPressed: _loading ? null : _refreshLocation,
            icon: const Icon(Icons.my_location_rounded),
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            if (_error != null) _ErrorBanner(message: _error!),

            // PHOTO SECTION
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Foto', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 240,
                        width: double.infinity,
                        color: cs.surfaceContainerHighest,
                        child: _photo == null
                            ? Center(
                                child: OutlinedButton.icon(
                                  onPressed: _loading ? null : _openCamera,
                                  icon: const Icon(Icons.camera_alt_rounded),
                                  label: const Text('Ambil Foto'),
                                ),
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(_photo!.path),
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    right: 12,
                                    top: 12,
                                    child: FilledButton.tonalIcon(
                                      onPressed: _loading ? null : _openCamera,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Ulang'),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // LOCATION SECTION
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Lokasi', style: TextStyle(fontWeight: FontWeight.w900)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _loading ? null : _refreshLocation,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Refresh'),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _address?.isNotEmpty == true ? _address! : 'Alamat belum tersedia',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              _InfoPill(
                                icon: Icons.gps_fixed_rounded,
                                text: 'LatLng: ${lat ?? "-"}, ${lng ?? "-"}',
                              ),
                              const SizedBox(height: 8),
                              _InfoPill(
                                icon: Icons.straighten_rounded,
                                text: 'Akurasi: ${acc ?? "-"} m',
                              ),
                              const SizedBox(height: 8),
                              _InfoPill(
                                icon: Icons.access_time_rounded,
                                text: 'Waktu: $nowStr',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // NOTES SECTION
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Catatan', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notesCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Tulis aktivitas sales hari ini...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _openCamera,
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: const Text('Ambil Foto'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _upload,
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: Text(_loading ? 'Mengirim...' : 'Kirim Report'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_loading) ...[
              const SizedBox(height: 14),
              Row(
                children: const [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Sedang memproses...', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              )
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
