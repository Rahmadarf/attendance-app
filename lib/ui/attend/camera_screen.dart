import 'package:attendance_app/ui/attend/attend_screen.dart';
import 'package:attendance_app/utils/face_detection/google_ml_kit.dart';
import 'package:camera/camera.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lottie/lottie.dart';

/// Layar pemindaian wajah: membuka kamera depan, mengambil selfie, lalu
/// memvalidasi keberadaan wajah dengan Google ML Kit sebelum lanjut ke form
/// presensi.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  CameraDescription? selectedCamera;
  bool isCameraReady = false;
  bool isBusy = false;
  String? cameraError;

  final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeCamera();
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
      setState(() => isCameraReady = false);
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

      selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final cameraController = CameraController(
        selectedCamera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await cameraController.initialize();
      if (!mounted) {
        await cameraController.dispose();
        return;
      }
      setState(() {
        controller = cameraController;
        isCameraReady = true;
        cameraError = null;
      });
    } catch (e) {
      debugPrint("Failed to initialize camera: $e");
      if (mounted) setState(() => cameraError = "Gagal membuka kamera: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    faceDetector.close();
    super.dispose();
  }

  Future<void> takeAndVerifySelfie() async {
    if (!isCameraReady || controller == null || isBusy) return;

    setState(() => isBusy = true);
    try {
      final imageFile = await controller!.takePicture();
      if (!mounted) return;

      _showLoaderDialog();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      await processImage(inputImage, imageFile);
    } catch (e) {
      if (!mounted) return;
      setState(() => isBusy = false);
      _showSnackBar("Gagal mengambil foto: $e", Icons.error_outline);
    }
  }

  Future<void> processImage(InputImage inputImage, XFile imageFile) async {
    try {
      final faces = await faceDetector.processImage(inputImage);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loader dialog
      setState(() => isBusy = false);

      if (faces.isNotEmpty) {
        // Wajah asli terdeteksi -> Lanjut ke layar form konfirmasi presensi
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AttendScreen(image: imageFile),
          ),
        );
      } else {
        _showSnackBar(
          "Wajah tidak terdeteksi! Pastikan wajah terlihat jelas di bingkai.",
          Icons.warning_amber_rounded,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => isBusy = false);
      _showSnackBar("Gagal memproses deteksi wajah: $e", Icons.error_outline);
    }
  }

  void _showLoaderDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Memverifikasi wajah...")),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1A008F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Face Verification")),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              const Text(
                "Posisikan wajah di dalam bingkai",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: isBusy ? null : takeAndVerifySelfie,
                icon: const Icon(Icons.camera_alt),
                label: Text(isBusy ? "Memverifikasi..." : "Ambil Selfie"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A008F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
