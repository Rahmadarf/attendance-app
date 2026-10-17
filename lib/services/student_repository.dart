import 'package:attendance_app/models/student.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Satu pintu akses ke koleksi `students`, supaya layar UI tidak perlu tahu
/// nama koleksi maupun bentuk dokumennya.
class StudentRepository {
  StudentRepository({FirebaseFirestore? firestore})
      : _collection =
            (firestore ?? FirebaseFirestore.instance).collection('students');

  final CollectionReference _collection;

  /// Stream realtime seluruh siswa, diurutkan berdasarkan nama di memori.
  ///
  /// Pengurutan dilakukan di sisi klien dengan alasan yang sama seperti pada
  /// riwayat presensi: menghindari keharusan membuat index di Firebase Console.
  Stream<List<Student>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final students = snapshot.docs.map(Student.fromDoc).toList();
      students.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return students;
    });
  }

  /// Ambil sekali untuk keperluan pencocokan wajah. Tidak perlu stream karena
  /// pencocokan hanya terjadi sesaat setelah foto diambil.
  Future<List<Student>> fetchAll() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map(Student.fromDoc)
        .where((student) => student.hasTemplates)
        .toList();
  }

  Future<void> add({
    required String name,
    required String nis,
    required String photoBase64,
    required List<FaceTemplate> templates,
  }) {
    final student = Student(
      id: '',
      name: name,
      nis: nis,
      photoBase64: photoBase64,
      templates: templates,
    );
    return _collection.add(student.toMap());
  }

  Future<void> delete(String id) => _collection.doc(id).delete();
}
