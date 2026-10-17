import 'package:camera/camera.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:lottie/lottie.dart';

/// Pegangan agar pemanggil bisa memotret tanpa menekan tombol di layar.
///
/// Dibutuhkan oleh uji keaktifan wajah: begitu tantangan kedipan dan gerakan
/// kepala lulus, foto diambil otomatis — pengguna tidak perlu menekan apa pun
/// untuk kedua kalinya.
class FaceCameraController {
  _FaceCameraViewState? _state;

  bool get isAttached => _state != null;

  /// Memotret satu foto. Mengembalikan null bila kamera belum siap.
  Future<XFile?> capture() async {
    final state = _state;
    if (state == null) return null;
    return state.capturePhoto();
  }
}

/// Preview kamera depan dengan bingkai pemindai, dipakai ulang oleh layar
/// presensi dan layar pendaftaran wajah.
///
/// Widget ini hanya mengurus hardware dan tampilan: inisialisasi
/// `CameraController`, lifecycle aplikasi, stream frame, overlay Lottie, dan
/// tombol ambil foto. Deteksi ML Kit maupun embedding diserahkan ke pemanggil,
/// supaya satu widget bisa melayani beberapa alur yang berbeda.
class FaceCameraView extends StatefulWidget {
  /// Teks instruksi di atas tombol, misalnya "Putar kepala sedikit ke kiri".
  final String instruction;

  /// Label tombol saat siap memotret.
  final String buttonLabel;

  /// Label tombol saat [isBusy] bernilai true.
  final String busyLabel;

  /// Dikendalikan pemanggil. Saat true, tombol dimatikan agar satu foto tidak
  /// diproses dua kali.
  final bool isBusy;

  /// Dipanggil setelah foto berhasil diambil lewat tombol di layar.
  final Future<void> Function(XFile file)? onCapture;

  /// Bila diisi, stream frame kamera dinyalakan dan setiap frame diteruskan ke
  /// callback ini. Pemanggil bertanggung jawab melewati frame saat masih sibuk.
  final void Function(CameraImage image, CameraDescription camera,
      DeviceOrientation orientation)? onFrame;

  /// Sembunyikan tombol bila pemotretan dipicu secara terprogram lewat
  /// [controller].
  final bool showCaptureButton;

  /// Konten tambahan di bawah teks instruksi, misalnya indikator progres.
  final Widget? overlayFooter;

  final FaceCameraController? controller;

  const FaceCameraView({
    super.key,
    required this.instruction,
    this.onCapture,
    this.onFrame,
    this.controller,
    this.overlayFooter,
    this.buttonLabel = "Ambil Foto",
    this.busyLabel = "Memproses...",
    this.isBusy = false,
    this.showCaptureButton = true,
  });

  @override
  State<FaceCameraView> createState() => _FaceCameraViewState();
}

class _FaceCameraViewState extends State<FaceCameraView>
    with WidgetsBindingObserver {
  CameraController? controller;
  CameraDescription? camera;
  bool isCameraReady = false;
  bool isStreaming = false;
  String? cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._state = this;
    initializeCamera();
  }

  @override
  void didUpdateWidget(FaceCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    // Pemanggil bisa menyalakan atau mematikan stream dengan mengisi atau
    // mengosongkan onFrame, misalnya saat sesi liveness dimulai.
    if ((oldWidget.onFrame == null) != (widget.onFrame == null)) {
      if (widget.onFrame == null) {
        _stopStream();
      } else {
        _startStream();
      }
    }
  }

  /// Android melepas handle kamera saat aplikasi masuk ke background. Tanpa
  /// re-inisialisasi, preview kembali dalam keadaan beku (layar hitam).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      setState(() {
        isCameraReady = false;
        isStreaming = false;
      });
      cameraController.dispose();
      controller = null;
    } else if (state == AppLifecycleState.resumed) {
      initializeCamera();
    }
  }

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            cameraError = "Tidak ada kamera yang tersedia pada perangkat ini.";
          });
        }
        return;
      }

      final frontCamera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: _formatGroupForPlatform(),
      );

      await cameraController.initialize();
      if (!mounted) {
        await cameraController.dispose();
        return;
      }
      setState(() {
        controller = cameraController;
        camera = frontCamera;
        isCameraReady = true;
        cameraError = null;
      });

      if (widget.onFrame != null) await _startStream();
    } catch (e) {
      debugPrint("Failed to initialize camera: $e");
      if (mounted) setState(() => cameraError = "Gagal membuka kamera: $e");
    }
  }

  /// ML Kit hanya menerima nv21 di Android dan bgra8888 di iOS saat membaca
  /// stream frame. `takePicture()` tetap menghasilkan JPEG terlepas dari
  /// pilihan ini.
  ///
  /// `defaultTargetPlatform` dipakai, bukan `Platform.isAndroid`, karena
  /// `dart:io` tidak ada di web dan file ini juga dikompilasi untuk Chrome.
  ImageFormatGroup _formatGroupForPlatform() {
    if (kIsWeb) return ImageFormatGroup.jpeg;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => ImageFormatGroup.nv21,
      TargetPlatform.iOS => ImageFormatGroup.bgra8888,
      _ => ImageFormatGroup.jpeg,
    };
  }

  Future<void> _startStream() async {
    final cameraController = controller;
    final activeCamera = camera;
    if (cameraController == null || activeCamera == null) return;
    if (isStreaming || !cameraController.value.isInitialized) return;

    // Flag dinaikkan sebelum await. Dua pemanggil yang datang berdekatan —
    // misalnya didUpdateWidget dan initializeCamera — tidak boleh sama-sama
    // lolos penjagaan di atas lalu memulai stream dua kali.
    isStreaming = true;
    try {
      await cameraController.startImageStream((image) {
        final onFrame = widget.onFrame;
        if (onFrame == null) return;
        onFrame(
          image,
          activeCamera,
          cameraController.value.deviceOrientation,
        );
      });
      if (mounted) setState(() {});
    } catch (e) {
      isStreaming = false;
      debugPrint("Failed to start image stream: $e");
    }
  }

  Future<void> _stopStream() async {
    final cameraController = controller;
    if (cameraController == null || !isStreaming) return;

    // Sama seperti _startStream: flag diturunkan lebih dulu agar pemanggil
    // kedua langsung keluar, bukan ikut memanggil stopImageStream.
    isStreaming = false;
    try {
      await cameraController.stopImageStream();
    } catch (e) {
      debugPrint("Failed to stop image stream: $e");
    }
    if (mounted) setState(() {});
  }

  /// Memotret satu foto.
  ///
  /// Stream dimatikan lebih dulu karena plugin camera tidak bisa melakukan
  /// stream dan `takePicture()` bersamaan, lalu dinyalakan lagi bila pemanggil
  /// masih membutuhkan frame.
  Future<XFile?> capturePhoto() async {
    final cameraController = controller;
    if (cameraController == null || !isCameraReady) return null;

    final shouldResume = isStreaming;
    await _stopStream();

    try {
      return await cameraController.takePicture();
    } catch (e) {
      debugPrint("Failed to take picture: $e");
      return null;
    } finally {
      if (shouldResume && mounted && widget.onFrame != null) {
        await _startStream();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._state = null;
    controller?.dispose();
    super.dispose();
  }

  Future<void> _onButtonPressed() async {
    final onCapture = widget.onCapture;
    if (onCapture == null || widget.isBusy) return;

    final file = await capturePhoto();
    if (!mounted) return;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal mengambil foto. Coba lagi."),
          backgroundColor: Color(0xFF1A008F),
        ),
      );
      return;
    }
    await onCapture(file);
  }

  @override
  Widget build(BuildContext context) {
    if (cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white54,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => cameraError = null);
                  initializeCamera();
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  "Coba Lagi",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!isCameraReady || controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: CameraPreview(controller!)),
        DottedBorder(
          borderType: BorderType.RRect,
          radius: const Radius.circular(24),
          dashPattern: const [8, 4],
          color: Colors.blueAccent,
          strokeWidth: 2,
          child: SizedBox(
            width: 260,
            height: 340,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Lottie.asset(
                  'assets/raw/face_id_ring.json',
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 24,
          right: 24,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              if (widget.overlayFooter != null) ...[
                const SizedBox(height: 12),
                widget.overlayFooter!,
              ],
              if (widget.showCaptureButton) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: widget.isBusy ? null : _onButtonPressed,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    widget.isBusy ? widget.busyLabel : widget.buttonLabel,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A008F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
