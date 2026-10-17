import 'dart:convert';

import 'package:attendance_app/models/student.dart';
import 'package:attendance_app/services/student_repository.dart';
import 'package:attendance_app/ui/attend/attend_screen.dart';
import 'package:attendance_app/ui/widgets/liveness_face_scanner.dart';
import 'package:attendance_app/ui/widgets/simulation_banner.dart';
import 'package:attendance_app/utils/face_detection/face_matcher.dart';
import 'package:attendance_app/utils/face_detection/face_recognition.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Skor yang dicatat untuk presensi yang dibuat di mode simulasi.
///
/// Diberi nilai negatif, bukan angka yang tampak masuk akal seperti 0,93, agar
/// dokumen hasil simulasi gampang dikenali dan dibersihkan dari Firestore.
const double kSimulatedSimilarity = -1.0;

/// Layar presensi: satu tombol, tanpa mengetik nama.
///
/// Alurnya: uji keaktifan wajah (berkedip dan menggerakkan kepala) → foto
/// diambil otomatis → ML Kit memastikan ada wajah → MobileFaceNet menghitung
/// embedding → dibandingkan ke seluruh siswa terdaftar → bila cocok, lanjut ke
/// layar konfirmasi dengan identitas yang sudah terisi.
///
/// Uji keaktifan berjalan lebih dulu dengan sengaja: tidak ada gunanya
/// mengenali wajah dari foto cetak, jadi keaslian subjek dibuktikan sebelum
/// identitasnya dicari.
///
/// Di Chrome, lapisan AI tidak tersedia. Alurnya tetap sama sampai foto
/// diambil, lalu penguji memilih siswa dari daftar sebagai pengganti hasil
/// pengenalan.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final FaceRecognitionBackend backend = createFaceRecognitionBackend();
  final StudentRepository repository = StudentRepository();

  bool isBusy = false;

  @override
  void dispose() {
    backend.dispose();
    super.dispose();
  }

  Future<void> _onCapture(XFile file) async {
    setState(() => isBusy = true);

    final outcome = await backend.scan(file);
    if (!mounted) return;

    if (!outcome.isSuccess) {
      setState(() => isBusy = false);
      _showSnackBar(outcome.error!, Icons.warning_amber_rounded);
      return;
    }

    final List<Student> students;
    try {
      students = await repository.fetchAll();
    } catch (e) {
      if (!mounted) return;
      setState(() => isBusy = false);
      _showSnackBar("Gagal memuat data siswa: $e", Icons.cloud_off);
      return;
    }
    if (!mounted) return;

    if (students.isEmpty) {
      setState(() => isBusy = false);
      _showSnackBar(
        "Belum ada wajah yang terdaftar. Daftarkan siswa lewat menu Data Wajah Siswa.",
        Icons.person_search_outlined,
      );
      return;
    }

    if (backend.isSimulation) {
      await _pickStudentManually(students, outcome);
      return;
    }

    final result = identify(outcome.embedding!, students);
    setState(() => isBusy = false);

    if (!result.isMatch) {
      _showUnrecognizedDialog(result);
      return;
    }

    _goToConfirmation(
      student: result.candidate!,
      similarity: result.similarity,
      outcome: outcome,
    );
  }

  /// Pengganti pencocokan otomatis di mode simulasi.
  ///
  /// Embedding di web hanya angka acak, jadi mencocokkannya tidak akan pernah
  /// menghasilkan jawaban yang benar. Lebih jujur meminta penguji memilih
  /// sendiri daripada memunculkan nama yang sebetulnya hasil kebetulan.
  Future<void> _pickStudentManually(
    List<Student> students,
    FaceScanOutcome outcome,
  ) async {
    final picked = await showDialog<Student>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.science_outlined,
          size: 36,
          color: Colors.orange,
        ),
        title: const Text("Mode Simulasi"),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pengenalan wajah tidak tersedia di browser. Pilih siswa untuk "
                "melanjutkan menguji alur presensi.",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return ListTile(
                      leading: _buildStudentAvatar(student),
                      title: Text(student.name),
                      subtitle: student.nis.isEmpty
                          ? null
                          : Text("NIS ${student.nis}"),
                      onTap: () => Navigator.pop(dialogContext, student),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Batal"),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => isBusy = false);
    if (picked == null) return;

    _goToConfirmation(
      student: picked,
      similarity: kSimulatedSimilarity,
      outcome: outcome,
    );
  }

  Widget _buildStudentAvatar(Student student) {
    if (student.photoBase64.isEmpty) {
      return const CircleAvatar(
        backgroundColor: Color(0xFF1A008F),
        child: Icon(Icons.person, color: Colors.white, size: 18),
      );
    }
    try {
      return CircleAvatar(
        backgroundImage: MemoryImage(base64Decode(student.photoBase64)),
      );
    } catch (_) {
      return const CircleAvatar(
        backgroundColor: Color(0xFF1A008F),
        child: Icon(Icons.person, color: Colors.white, size: 18),
      );
    }
  }

  void _goToConfirmation({
    required Student student,
    required double similarity,
    required FaceScanOutcome outcome,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AttendScreen(
          student: student,
          similarity: similarity,
          faceThumbnail: outcome.thumbnailJpg,
          isSimulation: backend.isSimulation,
        ),
      ),
    );
  }

  /// Wajah tak dikenali ditolak, bukan dipaksa cocok ke siswa terdekat. Skor
  /// tertinggi tetap ditampilkan supaya ambang batas bisa disetel berdasarkan
  /// angka nyata, bukan dugaan.
  void _showUnrecognizedDialog(RecognitionResult result) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.no_accounts_outlined,
          size: 40,
          color: Colors.redAccent,
        ),
        title: const Text("Wajah Tidak Dikenali"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Presensi dibatalkan. Minta guru mendaftarkan wajah Anda lewat "
              "menu Data Wajah Siswa, lalu coba lagi.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Kemiripan tertinggi: "
              "${(result.similarity * 100).toStringAsFixed(1)}% "
              "(ambang batas ${(kFaceMatchThreshold * 100).toStringAsFixed(0)}%)",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Coba Lagi"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text("Kembali"),
          ),
        ],
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
    final notice = backend.simulationNotice;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Presensi")),
      body: Column(
        children: [
          if (notice != null) SimulationBanner(message: notice),
          Expanded(
            child: LivenessFaceScanner(
              backend: backend,
              isBusy: isBusy,
              busyLabel: "Mengenali wajah...",
              onVerified: _onCapture,
            ),
          ),
        ],
      ),
    );
  }
}
