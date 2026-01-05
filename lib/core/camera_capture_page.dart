import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _cam;
  List<CameraDescription> _cams = [];
  int _camIndex = 0;
  bool _busy = true;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _cams = await availableCameras();
      await _startCamera(_camIndex);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context, null);
    }
  }

  Future<void> _startCamera(int idx) async {
    setState(() => _busy = true);
    await _cam?.dispose();
    _cam = CameraController(_cams[idx], ResolutionPreset.high, enableAudio: false);
    await _cam!.initialize();
    await _cam!.setFlashMode(_flash);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleFlash() async {
    if (_cam == null) return;
    final next = _flash == FlashMode.off ? FlashMode.auto : (_flash == FlashMode.auto ? FlashMode.torch : FlashMode.off);
    _flash = next;
    await _cam!.setFlashMode(_flash);
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cams.length < 2) return;
    _camIndex = (_camIndex + 1) % _cams.length;
    await _startCamera(_camIndex);
  }

  Future<void> _capture() async {
    if (_cam == null || !_cam!.value.isInitialized) return;
    final file = await _cam!.takePicture();
    if (!mounted) return;
    Navigator.pop(context, file);
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _busy || _cam == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(child: CameraPreview(_cam!)),

                  // Top bar
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context, null),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _toggleFlash,
                              icon: Icon(
                                _flash == FlashMode.off
                                    ? Icons.flash_off
                                    : (_flash == FlashMode.auto ? Icons.flash_auto : Icons.flash_on),
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: _switchCamera,
                              icon: const Icon(Icons.cameraswitch, color: Colors.white),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  // Bottom controls
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 22,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            "Arahkan kamera ke objek (toko/produk/aktivitas)",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: _capture,
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
