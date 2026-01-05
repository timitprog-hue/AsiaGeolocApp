import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'auth_storage.dart';
import 'api_client.dart';

class AuthImage extends StatefulWidget {
  final String url; // contoh: http://ip:8000/api/photos/9
  final BoxFit fit;
  final double? width;
  final double? height;

  const AuthImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends State<AuthImage> {
  Uint8List? bytes;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storage = AuthStorage();
      final api = ApiClient(storage);
      final token = await storage.getToken();

      final res = await api.dio.get<List<int>>(
        widget.url.replaceFirst(ApiClient.BASE_URL, ''), // biar tetap lewat dio baseUrl
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ),
      );

      setState(() => bytes = Uint8List.fromList(res.data ?? []));
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return const Center(child: Icon(Icons.broken_image, size: 36));
    }
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Image.memory(
      bytes!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }
}
