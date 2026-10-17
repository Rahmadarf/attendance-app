import 'dart:math' as math;

import 'package:attendance_app/models/student.dart';

/// Ambang batas kemiripan wajah.
///
/// Nilai cosine similarity berada di rentang -1 sampai 1; semakin dekat ke 1,
/// semakin mirip. 0.70 adalah titik awal yang wajar untuk MobileFaceNet.
/// Naikkan bila wajah orang lain ikut lolos, turunkan bila wajah yang sah
/// sering ditolak. Skor asli ditampilkan di layar konfirmasi presensi supaya
/// penyetelan ini punya dasar data, bukan dugaan.
const double kFaceMatchThreshold = 0.70;

/// Hasil pencocokan satu wajah terhadap seluruh siswa terdaftar.
class RecognitionResult {
  /// Siswa dengan skor tertinggi, atau null bila daftar siswa kosong.
  final Student? candidate;

  /// Skor tertinggi yang dicapai [candidate].
  final double similarity;

  const RecognitionResult({required this.candidate, required this.similarity});

  /// Pengenalan dianggap berhasil hanya bila ada kandidat dan skornya melewati
  /// ambang batas.
  bool get isMatch => candidate != null && similarity >= kFaceMatchThreshold;

  static const RecognitionResult empty =
      RecognitionResult(candidate: null, similarity: 0);
}

/// Membagi setiap elemen dengan panjang vektor (norma L2).
///
/// Setelah dinormalisasi, cosine similarity antara dua vektor cukup dihitung
/// sebagai dot product — tanpa pembagian lagi.
List<double> l2Normalize(List<double> vector) {
  double sumOfSquares = 0;
  for (final value in vector) {
    sumOfSquares += value * value;
  }

  final norm = math.sqrt(sumOfSquares);
  if (norm == 0) return List<double>.filled(vector.length, 0);

  return vector.map((value) => value / norm).toList(growable: false);
}

/// Cosine similarity dua vektor yang sudah dinormalisasi L2.
///
/// Melempar [ArgumentError] bila panjangnya berbeda, karena itu tanda embedding
/// dibuat oleh model dengan dimensi output yang tidak sama.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError(
      'Panjang vektor berbeda: ${a.length} dan ${b.length}. '
      'Pastikan semua embedding dibuat oleh model yang sama.',
    );
  }

  double dotProduct = 0;
  for (var i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
  }
  return dotProduct;
}

/// Skor satu siswa adalah skor tertinggi di antara seluruh template-nya.
///
/// Diambil nilai tertinggi, bukan rata-rata: cukup satu pose yang cocok untuk
/// membuktikan identitas, sementara pose lain yang berbeda jauh justru akan
/// menyeret rata-rata ke bawah tanpa alasan.
double bestSimilarityFor(Student student, List<double> probe) {
  double best = -1;
  for (final template in student.templates) {
    if (template.vector.length != probe.length) continue;
    final score = cosineSimilarity(template.vector, probe);
    if (score > best) best = score;
  }
  return best == -1 ? 0 : best;
}

/// Identifikasi 1:N — bandingkan satu wajah terhadap seluruh siswa terdaftar.
///
/// Mengembalikan kandidat terbaik beserta skornya. Keputusan diterima atau
/// ditolak diserahkan ke [RecognitionResult.isMatch], supaya skor mentah tetap
/// bisa ditampilkan walaupun pengenalan gagal.
RecognitionResult identify(List<double> probe, List<Student> students) {
  if (probe.isEmpty || students.isEmpty) return RecognitionResult.empty;

  Student? best;
  double bestScore = -1;

  for (final student in students) {
    if (!student.hasTemplates) continue;
    final score = bestSimilarityFor(student, probe);
    if (score > bestScore) {
      bestScore = score;
      best = student;
    }
  }

  if (best == null) return RecognitionResult.empty;
  return RecognitionResult(candidate: best, similarity: bestScore);
}
