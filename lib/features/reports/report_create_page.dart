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
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('GPS/Location service mati');

    LocationPermission perm = await Geolocator.checkPermission();
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

  Future<void> _upload() async {
    if (_pos == null) {
      setState(() => _error = 'Lokasi belum ada. Coba refresh lokasi.');
      return;
    }
    if (_photo == null) {
      setState(() => _error = 'Foto belum diambil');
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

      // FIX: backend pakai "address"
      'address': _address ?? '',

      'notes': _notesCtrl.text.trim(),
    });


      await api.dio.post('/reports', data: form);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Upload gagal: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat("dd MMM yyyy • HH:mm").format(DateTime.now());

    final lat = _pos?.latitude.toStringAsFixed(6);
    final lng = _pos?.longitude.toStringAsFixed(6);
    final acc = _pos?.accuracy.toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Report'),
        actions: [
          IconButton(
            onPressed: _loading
                ? null
                : () async {
                    setState(() => _error = null);
                    await _getLocation();
                    await _reverseGeocode();
                  },
            icon: const Icon(Icons.my_location),
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.25)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 12),

            // Photo preview
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: _photo == null
                  ? Center(
                      child: TextButton.icon(
                        onPressed: _loading ? null : _openCamera,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Ambil Foto'),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(File(_photo!.path), fit: BoxFit.cover),
                    ),
            ),

            const SizedBox(height: 12),

            // Location card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _address?.isNotEmpty == true ? _address! : 'Alamat belum tersedia',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text('LatLng: ${lat ?? "-"}, ${lng ?? "-"} • akurasi: ${acc ?? "-"} m'),
                        const SizedBox(height: 6),
                        Text('Waktu: $nowStr'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            const Text('Catatan', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Tulis aktivitas sales hari ini...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _openCamera,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Ambil Foto'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _upload,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(_loading ? 'Mengirim...' : 'Kirim Report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
