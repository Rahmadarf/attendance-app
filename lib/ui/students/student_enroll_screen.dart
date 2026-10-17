import 'dart:convert';
import 'dart:typed_data';

import 'package:attendance_app/models/student.dart';
import 'package:attendance_app/services/student_repository.dart';
import 'package:attendance_app/ui/widgets/face_camera_view.dart';
import 'package:attendance_app/ui/widgets/simulation_banner.dart';
import 'package:attendance_app/utils/face_detection/face_recognition.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Batas minimal sudut putar kepala agar pose kiri dan kanan dianggap benar.
///
/// Tanpa pemeriksaan ini, siswa bisa menekan tombol tiga kali dengan pose yang
/// persis sama — ketiga template jadi kembar dan tidak menambah akurasi apa pun.
const double kMinHeadTurnAngle = 10.0;

/// Wizard pendaftaran wajah: tiga pose, lalu nama dan NIS.
class StudentEnrollScreen extends StatefulWidget {
  const StudentEnrollScreen({super.key});

  @override
  State<StudentEnrollScreen> createState() => _StudentEnrollScreenState();
}

class _StudentEnrollScreenState extends State<StudentEnrollScreen> {
  final FaceRecognitionBackend backend = createFaceRecognitionBackend();
  final StudentRepository repository = StudentRepository();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController nisController = TextEditingController();

  final List<FaceTemplate> captured = [];
  Uint8List? frontThumbnail;

  bool isBusy = false;
  bool isSaving = false;

  /// Pose yang sedang diminta, atau null bila ketiganya sudah terkumpul.
  FacePose? get currentPose =>
      captured.length < FacePose.values.length
          ? FacePose.values[captured.length]
          : null;

  @override
  void dispose() {
    backend.dispose();
    nameController.dispose();
    nisController.dispose();
    super.dispose();
  }

  Future<void> _onCapture(XFile file) async {
    final pose = currentPose;
    if (pose == null) return;

    setState(() => isBusy = true);
    final outcome = await backend.scan(file);
    if (!mounted) return;

    if (!outcome.isSuccess) {
      setState(() => isBusy = false);
      _showSnackBar(outcome.error!, Icons.warning_amber_rounded);
      return;
    }

    final poseError = _validatePose(pose, outcome.headEulerAngleY);
    if (poseError != null) {
      setState(() => isBusy = false);
      _showSnackBar(poseError, Icons.screen_rotation_alt_outlined);
      return;
    }

    setState(() {
      captured.add(
        FaceTemplate(pose: pose, vector: outcome.embedding!),
      );
      if (pose == FacePose.front) frontThumbnail = outcome.thumbnailJpg;
      isBusy = false;
    });
  }

  /// ML Kit memberi sudut positif untuk kepala yang menoleh ke satu arah dan
  /// negatif untuk arah sebaliknya. Karena arah tandanya bergantung pada
  /// orientasi citra kamera depan, yang diperiksa hanya besarnya — cukup untuk
  /// memastikan kepala benar-benar menoleh, tanpa menolak perangkat yang
  /// kebetulan membalik tandanya.
  String? _validatePose(FacePose pose, double? headEulerAngleY) {
    if (pose == FacePose.front) {
      if (headEulerAngleY != null && headEulerAngleY.abs() > 20) {
        return "Untuk pose ini, hadapkan wajah lurus ke kamera.";
      }
      return null;
    }

    if (headEulerAngleY == null) {
      // Perangkat tidak melaporkan sudut, atau sedang di mode simulasi tanpa
      // ML Kit. Jangan blokir pendaftaran hanya karena data tambahan ini tidak
      // tersedia.
      return null;
    }

    if (headEulerAngleY.abs() < kMinHeadTurnAngle) {
      return "Putar kepala lebih jauh agar posenya berbeda dari pose depan.";
    }
    return null;
  }

  void _retakeAll() {
    setState(() {
      captured.clear();
      frontThumbnail = null;
    });
  }

  Future<void> _save() async {
    if (isSaving) return;

    if (nameController.text.trim().isEmpty) {
      _showSnackBar("Nama wajib diisi.", Icons.warning_amber_rounded);
      return;
    }
    if (captured.length != FacePose.values.length || frontThumbnail == null) {
      _showSnackBar(
        "Ambil ketiga pose terlebih dahulu.",
        Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await repository.add(
        name: nameController.text,
        nis: nisController.text,
        photoBase64: base64Encode(frontThumbnail!),
        templates: captured,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showSnackBar("Gagal menyimpan data siswa: $e", Icons.error_outline);
    }
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
    final pose = currentPose;

    return Scaffold(
      backgroundColor: pose == null ? Colors.white : Colors.black,
      appBar: AppBar(
        title: Text(
          pose == null
              ? "Data Siswa"
              : "Pose ${captured.length + 1} dari ${FacePose.values.length}",
        ),
      ),
      body: Column(
        children: [
          if (backend.simulationNotice != null)
            SimulationBanner(message: backend.simulationNotice!),
          Expanded(child: pose == null ? _buildForm() : _buildCapture(pose)),
        ],
      ),
    );
  }

  Widget _buildCapture(FacePose pose) {
    return Column(
      children: [
        _buildProgressBar(),
        Expanded(
          child: FaceCameraView(
            instruction: pose.instruction,
            buttonLabel: "Ambil Pose Ini",
            busyLabel: "Memeriksa wajah...",
            isBusy: isBusy,
            onCapture: _onCapture,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: FacePose.values.map((pose) {
          final index = FacePose.values.indexOf(pose);
          final done = index < captured.length;
          final active = index == captured.length;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: done
                          ? Colors.greenAccent
                          : active
                              ? Colors.blueAccent
                              : Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pose.id,
                    style: TextStyle(
                      fontSize: 11,
                      color: done || active ? Colors.white : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildForm() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  frontThumbnail!,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "${captured.length} pose wajah tersimpan",
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Nama Lengkap",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nisController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "NIS (opsional)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
                helperText: "Membedakan siswa yang namanya sama",
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: isSaving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(isSaving ? "Menyimpan..." : "Simpan Data Wajah"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A008F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: isSaving ? null : _retakeAll,
              icon: const Icon(Icons.refresh),
              label: const Text("Ambil Ulang Ketiga Pose"),
            ),
          ],
        ),
      ),
    );
  }
}
