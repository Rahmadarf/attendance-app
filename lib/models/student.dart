import 'package:cloud_firestore/cloud_firestore.dart';

/// Pose wajah yang direkam saat pendaftaran. Tiga sudut berbeda membuat
/// pencocokan tidak gagal hanya karena kepala siswa sedikit miring.
enum FacePose {
  front('front', 'Lihat lurus ke kamera'),
  left('left', 'Putar kepala sedikit ke kiri'),
  right('right', 'Putar kepala sedikit ke kanan');

  const FacePose(this.id, this.instruction);

  final String id;
  final String instruction;

  static FacePose fromId(String id) => FacePose.values.firstWhere(
        (pose) => pose.id == id,
        orElse: () => FacePose.front,
      );
}

/// Satu embedding wajah beserta pose asalnya.
class FaceTemplate {
  final FacePose pose;
  final List<double> vector;

  const FaceTemplate({required this.pose, required this.vector});

  Map<String, dynamic> toMap() => {
        'pose': pose.id,
        'vector': vector,
      };

  /// Firestore menyimpan angka sebagai `num`, jadi tiap elemen dikonversi
  /// eksplisit ke `double`.
  static FaceTemplate? fromMap(Map<String, dynamic> map) {
    final rawVector = map['vector'];
    if (rawVector is! List || rawVector.isEmpty) return null;

    final vector = <double>[];
    for (final value in rawVector) {
      if (value is num) vector.add(value.toDouble());
    }
    if (vector.length != rawVector.length) return null;

    return FaceTemplate(
      pose: FacePose.fromId(map['pose']?.toString() ?? 'front'),
      vector: vector,
    );
  }
}

/// Siswa yang wajahnya sudah terdaftar.
class Student {
  final String id;
  final String name;
  final String nis;

  /// Thumbnail 112x112 pose depan dalam base64, untuk ditampilkan di daftar.
  final String photoBase64;

  final List<FaceTemplate> templates;

  const Student({
    required this.id,
    required this.name,
    required this.nis,
    required this.photoBase64,
    required this.templates,
  });

  bool get hasTemplates => templates.isNotEmpty;

  /// Label pendek untuk ditampilkan di kartu riwayat dan layar konfirmasi.
  String get label => nis.isEmpty ? name : '$name · $nis';

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'nis': nis.trim(),
        'photo_base64': photoBase64,
        'templates': templates.map((template) => template.toMap()).toList(),
        'created_at': FieldValue.serverTimestamp(),
      };

  static Student fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawTemplates = data['templates'];

    final templates = <FaceTemplate>[];
    if (rawTemplates is List) {
      for (final entry in rawTemplates) {
        if (entry is Map) {
          final template = FaceTemplate.fromMap(
            Map<String, dynamic>.from(entry),
          );
          if (template != null) templates.add(template);
        }
      }
    }

    return Student(
      id: doc.id,
      name: data['name']?.toString() ?? 'Unknown',
      nis: data['nis']?.toString() ?? '',
      photoBase64: data['photo_base64']?.toString() ?? '',
      templates: templates,
    );
  }
}
