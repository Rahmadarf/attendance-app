import 'dart:convert';

import 'package:attendance_app/models/student.dart';
import 'package:attendance_app/services/admin_session.dart';
import 'package:attendance_app/services/student_repository.dart';
import 'package:attendance_app/ui/students/student_enroll_screen.dart';
import 'package:flutter/material.dart';

/// Daftar siswa yang wajahnya sudah terdaftar, beserta tombol tambah dan hapus.
class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final StudentRepository repository = StudentRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Wajah Siswa"),
        actions: [
          IconButton(
            tooltip: "Kunci sekarang",
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              AdminSession.instance.lock();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A008F),
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StudentEnrollScreen(),
            ),
          );
          // Mendaftarkan satu kelas bisa memakan waktu lebih lama dari batas
          // sesi admin. Setiap kali kembali dari pendaftaran dianggap tanda
          // admin masih aktif, jadi hitungannya dimulai ulang.
          AdminSession.instance.touch(DateTime.now());
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text("Daftarkan Wajah"),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Student>>(
          stream: repository.watchAll(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildMessage(
                Icons.cloud_off,
                "Gagal memuat data siswa: ${snapshot.error}",
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final students = snapshot.data ?? const <Student>[];
            if (students.isEmpty) {
              return _buildMessage(
                Icons.person_search_outlined,
                "Belum ada wajah yang terdaftar.\n"
                "Tekan \"Daftarkan Wajah\" untuk menambahkan siswa.",
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: students.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildCard(students[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(Student student) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildAvatar(student),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (student.nis.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "NIS ${student.nis}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    "${student.templates.length} pose wajah tersimpan",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: "Hapus",
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              onPressed: () => _confirmDelete(student),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Student student) {
    if (student.photoBase64.isEmpty) {
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFF1A008F),
        child: Icon(Icons.person, color: Colors.white),
      );
    }

    // Foto rusak atau base64 tidak valid tidak boleh menjatuhkan seluruh
    // daftar, jadi dekode dibungkus try/catch dan jatuh ke ikon biasa.
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          base64Decode(student.photoBase64),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFF1A008F),
        child: Icon(Icons.person, color: Colors.white),
      );
    }
  }

  Future<void> _confirmDelete(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Hapus Data Wajah"),
        content: Text(
          "Hapus data wajah ${student.name}? "
          "Setelah dihapus, siswa ini tidak bisa melakukan presensi sampai "
          "wajahnya didaftarkan ulang.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await repository.delete(student.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal menghapus: $e"),
          backgroundColor: const Color(0xFF1A008F),
        ),
      );
    }
  }

  Widget _buildMessage(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
