import 'dart:math' as math;

import 'package:attendance_app/models/student.dart';
import 'package:attendance_app/utils/face_detection/face_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// Membuat siswa palsu dengan template yang sudah dinormalisasi, supaya test
/// tidak bergantung pada model TFLite maupun Firestore.
Student makeStudent(
  String id,
  String name,
  List<List<double>> rawVectors,
) {
  return Student(
    id: id,
    name: name,
    nis: '',
    photoBase64: '',
    templates: [
      for (var i = 0; i < rawVectors.length; i++)
        FaceTemplate(
          pose: FacePose.values[i % FacePose.values.length],
          vector: l2Normalize(rawVectors[i]),
        ),
    ],
  );
}

void main() {
  group('l2Normalize', () {
    test('panjang vektor hasil normalisasi selalu 1', () {
      final normalized = l2Normalize([3, 4]);
      expect(normalized[0], closeTo(0.6, 1e-9));
      expect(normalized[1], closeTo(0.8, 1e-9));

      final length = math.sqrt(
        normalized.fold<double>(0, (sum, v) => sum + v * v),
      );
      expect(length, closeTo(1.0, 1e-9));
    });

    test('vektor nol tidak memicu pembagian dengan nol', () {
      expect(l2Normalize([0, 0, 0]), [0, 0, 0]);
    });
  });

  group('cosineSimilarity', () {
    test('vektor identik menghasilkan skor 1', () {
      final v = l2Normalize([1, 2, 3, 4]);
      expect(cosineSimilarity(v, v), closeTo(1.0, 1e-9));
    });

    test('vektor tegak lurus menghasilkan skor 0', () {
      final a = l2Normalize([1, 0]);
      final b = l2Normalize([0, 1]);
      expect(cosineSimilarity(a, b), closeTo(0.0, 1e-9));
    });

    test('vektor berlawanan arah menghasilkan skor -1', () {
      final a = l2Normalize([1, 1]);
      final b = l2Normalize([-1, -1]);
      expect(cosineSimilarity(a, b), closeTo(-1.0, 1e-9));
    });

    test('panjang vektor berbeda ditolak, bukan dihitung diam-diam', () {
      expect(
        () => cosineSimilarity([1, 0], [1, 0, 0]),
        throwsArgumentError,
      );
    });
  });

  group('bestSimilarityFor', () {
    test('mengambil skor tertinggi, bukan rata-rata', () {
      final probe = l2Normalize([1, 0, 0]);
      final student = makeStudent('s1', 'Rahmad', [
        [1, 0, 0], // cocok sempurna
        [0, 1, 0], // tegak lurus
        [0, 0, 1], // tegak lurus
      ]);

      // Rata-rata ketiganya hanya 0.33, sedangkan nilai tertinggi 1.0.
      expect(bestSimilarityFor(student, probe), closeTo(1.0, 1e-9));
    });

    test('template dengan dimensi berbeda dilewati, tidak membuat crash', () {
      final probe = l2Normalize([1, 0, 0]);
      final student = Student(
        id: 's1',
        name: 'Rahmad',
        nis: '',
        photoBase64: '',
        templates: [
          FaceTemplate(pose: FacePose.front, vector: l2Normalize([1, 0])),
          FaceTemplate(pose: FacePose.left, vector: l2Normalize([1, 0, 0])),
        ],
      );

      expect(bestSimilarityFor(student, probe), closeTo(1.0, 1e-9));
    });
  });

  group('identify', () {
    final budi = makeStudent('s1', 'Budi', [
      [1, 0, 0, 0],
      [0.9, 0.1, 0, 0],
    ]);
    final siti = makeStudent('s2', 'Siti', [
      [0, 1, 0, 0],
      [0, 0.9, 0.1, 0],
    ]);
    final students = [budi, siti];

    test('memilih siswa yang satu pose-nya paling mirip', () {
      final probe = l2Normalize([0.95, 0.05, 0, 0]);
      final result = identify(probe, students);

      expect(result.candidate?.name, 'Budi');
      expect(result.isMatch, isTrue);
      expect(result.similarity, greaterThan(kFaceMatchThreshold));
    });

    test('wajah yang tidak mirip siapa pun ditolak, bukan dipaksa cocok', () {
      final probe = l2Normalize([0, 0, 0, 1]);
      final result = identify(probe, students);

      // Tetap ada kandidat terdekat supaya skornya bisa ditampilkan,
      // tapi keputusannya harus tolak.
      expect(result.candidate, isNotNull);
      expect(result.similarity, lessThan(kFaceMatchThreshold));
      expect(result.isMatch, isFalse);
    });

    test('daftar siswa kosong menghasilkan hasil kosong', () {
      final result = identify(l2Normalize([1, 0, 0, 0]), []);
      expect(result.candidate, isNull);
      expect(result.isMatch, isFalse);
    });

    test('probe kosong menghasilkan hasil kosong', () {
      expect(identify([], students).isMatch, isFalse);
    });

    test('siswa tanpa template dilewati', () {
      final kosong = Student(
        id: 's3',
        name: 'Tanpa Wajah',
        nis: '',
        photoBase64: '',
        templates: const [],
      );
      final result = identify(l2Normalize([1, 0, 0, 0]), [kosong, budi]);
      expect(result.candidate?.name, 'Budi');
    });
  });
}
