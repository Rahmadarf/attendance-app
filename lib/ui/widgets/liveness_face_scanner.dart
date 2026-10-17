import 'package:attendance_app/ui/widgets/face_camera_view.dart';
import 'package:attendance_app/utils/face_detection/face_recognition.dart';
import 'package:attendance_app/utils/face_detection/liveness_session.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

/// Pemindai wajah dengan uji keaktifan.
///
/// Pengguna menekan satu tombol, lalu diminta berkedip dan menggerakkan kepala.
/// Foto hanya diambil setelah kedua tantangan itu lulus, sehingga foto cetak
/// atau foto di layar ponsel lain tidak bisa dipakai untuk presensi.
///
/// Widget ini menumpuk di atas [FaceCameraView]: urusan kamera tetap di sana,
/// di sini hanya logika tantangan dan tampilan panduannya.
///
/// Bila [backend] tidak mendukung uji keaktifan — misalnya di Chrome, karena
/// menilai kedipan butuh ML Kit — tantangan dilewati dan tombolnya langsung
/// memotret, dengan penanda yang jelas bahwa verifikasi tidak dijalankan.
class LivenessFaceScanner extends StatefulWidget {
  /// Backend pengenalan wajah, dimiliki dan dilepas oleh pemanggil.
  final FaceRecognitionBackend backend;

  /// Dipanggil setelah uji keaktifan lulus dan foto berhasil diambil.
  final Future<void> Function(XFile file) onVerified;

  /// Saat true, tombol dan pemrosesan frame dihentikan. Diisi pemanggil selama
  /// foto sedang diproses.
  final bool isBusy;

  /// Label yang ditampilkan saat [isBusy].
  final String busyLabel;

  const LivenessFaceScanner({
    super.key,
    required this.backend,
    required this.onVerified,
    this.isBusy = false,
    this.busyLabel = "Memproses...",
  });

  @override
  State<LivenessFaceScanner> createState() => _LivenessFaceScannerState();
}

class _LivenessFaceScannerState extends State<LivenessFaceScanner> {
  final FaceCameraController cameraController = FaceCameraController();

  LivenessSession session = LivenessSession.random();

  /// Mencegah frame menumpuk: ML Kit lebih lambat dari laju frame kamera, jadi
  /// frame yang datang saat deteksi masih berjalan dilewati saja.
  bool isDetecting = false;

  bool isRunning = false;
  bool isCapturing = false;
  String instruction = "Tekan tombol untuk memulai verifikasi";
  double progress = 0;

  bool get supportsLiveness => widget.backend.supportsLiveness;

  @override
  void initState() {
    super.initState();
    if (!supportsLiveness) {
      instruction = "Uji keaktifan tidak tersedia di browser";
    }
  }

  void _start() {
    // Urutan tantangan diacak ulang tiap percobaan, supaya rekaman video satu
    // sesi tidak bisa diputar ulang pada sesi berikutnya.
    session = LivenessSession.random();
    final update = session.start(DateTime.now());
    setState(() {
      isRunning = true;
      instruction = update.instruction;
      progress = update.progress;
    });
  }

  Future<void> _onFrame(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation orientation,
  ) async {
    if (!isRunning || isDetecting || isCapturing || widget.isBusy) return;

    isDetecting = true;
    try {
      final signals = await widget.backend.analyzeFrame(
        image: image,
        camera: camera,
        orientation: orientation,
      );
      if (!mounted || signals == null) return;

      final update = session.update(signals, DateTime.now());
      setState(() {
        instruction = update.instruction;
        progress = update.progress;
      });

      switch (update.status) {
        case LivenessStatus.passed:
          await _capture("Verifikasi berhasil, mengambil foto...");
        case LivenessStatus.failed:
          setState(() => isRunning = false);
        case LivenessStatus.running:
        case LivenessStatus.idle:
          break;
      }
    } catch (e) {
      debugPrint("Liveness frame gagal diproses: $e");
    } finally {
      isDetecting = false;
    }
  }

  Future<void> _capture(String label) async {
    if (isCapturing) return;
    setState(() {
      isCapturing = true;
      isRunning = false;
      instruction = label;
    });

    final file = await cameraController.capture();
    if (!mounted) return;

    if (file == null) {
      setState(() {
        isCapturing = false;
        instruction = "Gagal mengambil foto. Coba lagi.";
      });
      return;
    }

    await widget.onVerified(file);
    if (mounted) setState(() => isCapturing = false);
  }

  @override
  Widget build(BuildContext context) {
    final showButton = !isRunning && !isCapturing && !widget.isBusy;

    return FaceCameraView(
      controller: cameraController,
      instruction: widget.isBusy ? widget.busyLabel : instruction,
      // Stream hanya dinyalakan selama sesi berjalan, dan hanya bila platform
      // ini memang bisa menilai frame. Di luar itu kamera cukup menampilkan
      // preview, tanpa membebani perangkat dengan deteksi.
      onFrame: isRunning && supportsLiveness ? _onFrame : null,
      showCaptureButton: false,
      overlayFooter: _buildFooter(showButton),
    );
  }

  Widget _buildFooter(bool showButton) {
    return Column(
      children: [
        if (isRunning && supportsLiveness) _buildProgress(),
        if (showButton) ...[
          const SizedBox(height: 4),
          ElevatedButton.icon(
            onPressed: supportsLiveness
                ? _start
                : () => _capture("Mengambil foto..."),
            icon: Icon(
              supportsLiveness
                  ? Icons.verified_user_outlined
                  : Icons.camera_alt,
            ),
            label: Text(_buttonLabel()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A008F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
        if (isCapturing || widget.isBusy) ...[
          const SizedBox(height: 12),
          const CircularProgressIndicator(color: Colors.white),
        ],
      ],
    );
  }

  String _buttonLabel() {
    if (!supportsLiveness) return "Absen Tanpa Uji Keaktifan";
    return session.status == LivenessStatus.failed
        ? "Coba Lagi"
        : "Absen Sekarang";
  }

  Widget _buildProgress() {
    return Column(
      children: [
        Row(
          children: List.generate(session.challenges.length, (index) {
            final done = index < session.passedCount;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: done ? Colors.greenAccent : Colors.white30,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          "${session.passedCount} dari ${session.challenges.length} tantangan lulus",
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}
