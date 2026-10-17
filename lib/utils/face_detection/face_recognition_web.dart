import 'dart:math';
import 'dart:typed_data';

import 'package:attendance_app/utils/face_detection/face_matcher.dart';
import 'package:attendance_app/utils/face_detection/face_model_spec.dart';
import 'package:attendance_app/utils/face_detection/face_recognition_types.dart';
import 'package:attendance_app/utils/face_detection/liveness_session.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:image/image.dart' as img;

FaceRecognitionBackend createBackend() => SimulatedFaceRecognition();

/// Pengganti lapisan pengenalan wajah untuk web.
///
/// Browser tidak bisa menjalankan MobileFaceNet (`dart:ffi` tidak ada) maupun
/// Google ML Kit (tidak punya implementasi web). Jadi di Chrome, bagian AI
/// diganti mode simulasi supaya sisa aplikasinya — webcam, GPS, Firestore,
/// seluruh layar dan alur navigasi — tetap bisa diuji di komputer tanpa HP.
///
/// Yang tetap sungguhan di sini: foto diambil dari webcam, dipotong dan
/// diperkecil ke 112x112 memakai package `image` yang murni Dart. Jadi foto
/// siswa yang tersimpan di Firestore adalah foto asli.
///
/// Yang disimulasikan: embedding-nya angka acak, bukan ciri wajah. Karena itu
/// pencocokan otomatis tidak mungkin dilakukan — layar presensi di mode ini
/// meminta penguji memilih siswa dari daftar.
class SimulatedFaceRecognition implements FaceRecognitionBackend {
  final Random _random = Random();

  @override
  bool get isSimulation => true;

  @override
  String? get simulationNotice =>
      'MODE SIMULASI — browser tidak bisa menjalankan MobileFaceNet maupun '
      'ML Kit. Wajah tidak benar-benar dikenali. Jalankan di HP Android untuk '
      'pengenalan sungguhan.';

  @override
  bool get supportsLiveness => false;

  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<FaceScanOutcome> scan(XFile file) async {
    // `XFile.readAsBytes()` bekerja di web maupun native, berbeda dari
    // `File(path).readAsBytes()` yang butuh dart:io.
    final bytes = await file.readAsBytes();

    final thumbnail = _buildThumbnail(bytes);
    if (thumbnail == null) {
      return const FaceScanOutcome.failure(
        "Foto tidak bisa dibaca. Coba ambil ulang.",
      );
    }

    return FaceScanOutcome(
      embedding: _pseudoEmbedding(),
      thumbnailJpg: thumbnail,
    );
  }

  /// Tanpa ML Kit tidak ada bounding box wajah, jadi yang dipotong adalah
  /// kotak tengah gambar. Hasilnya tetap foto asli, hanya kerangkanya tidak
  /// dituntun oleh deteksi wajah.
  Uint8List? _buildThumbnail(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final oriented = img.bakeOrientation(decoded);
    final side = min(oriented.width, oriented.height);
    final square = img.copyCrop(
      oriented,
      x: (oriented.width - side) ~/ 2,
      y: (oriented.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final resized = img.copyResize(
      square,
      width: kFaceInputSize,
      height: kFaceInputSize,
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  /// Vektor acak dengan panjang dan normalisasi yang sama seperti keluaran
  /// MobileFaceNet sungguhan.
  ///
  /// Nilainya tidak berarti apa-apa. Tujuannya hanya agar bentuk dokumen yang
  /// ditulis ke Firestore identik dengan yang ditulis aplikasi Android, supaya
  /// yang diuji di Chrome betul-betul jalur penyimpanan yang sama.
  List<double> _pseudoEmbedding() {
    return l2Normalize(
      List<double>.generate(
        kEmbeddingLength,
        (_) => _random.nextDouble() * 2 - 1,
      ),
    );
  }

  @override
  Future<FaceSignals?> analyzeFrame({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation orientation,
  }) async =>
      null;

  @override
  void dispose() {}
}
