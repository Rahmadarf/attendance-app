import 'package:attendance_app/utils/face_detection/face_cropper.dart';
import 'package:attendance_app/utils/face_detection/face_matcher.dart';
import 'package:attendance_app/utils/face_detection/face_model_spec.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Pembungkus model MobileFaceNet: mengubah potongan wajah menjadi embedding.
///
/// Dibuat singleton karena model berukuran sekitar 5 MB — memuatnya ulang tiap
/// kali layar dibuka akan membuang memori dan waktu.
class FaceEmbedder {
  FaceEmbedder._();
  static final FaceEmbedder instance = FaceEmbedder._();

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  String? _loadError;
  bool _loadAttempted = false;

  /// Pesan kegagalan terakhir, atau null bila model siap dipakai.
  String? get loadError => _loadError;

  bool get isReady => _isolateInterpreter != null;

  /// Memuat model bila belum dimuat. Aman dipanggil berulang kali.
  ///
  /// Mengembalikan null bila berhasil, atau pesan kesalahan yang siap
  /// ditampilkan ke pengguna.
  Future<String?> ensureReady() async {
    if (isReady) return null;
    if (_loadAttempted) return _loadError;

    _loadAttempted = true;
    try {
      final interpreter = await Interpreter.fromAsset(kFaceModelAsset);
      // Inferensi dijalankan di isolate terpisah supaya animasi dan preview
      // kamera tidak tersendat saat model bekerja.
      final isolateInterpreter = await IsolateInterpreter.create(
        address: interpreter.address,
      );

      _interpreter = interpreter;
      _isolateInterpreter = isolateInterpreter;
      _loadError = null;
    } catch (e) {
      debugPrint('Gagal memuat $kFaceModelAsset: $e');
      _loadError = kModelMissingMessage;
    }
    return _loadError;
  }

  /// Menjalankan model terhadap satu wajah yang sudah dipotong.
  ///
  /// Hasilnya sudah dinormalisasi L2, jadi bisa langsung dibandingkan dengan
  /// [cosineSimilarity]. Melempar [StateError] bila model belum siap.
  Future<List<double>> embed(CroppedFace face) async {
    final interpreter = _isolateInterpreter;
    if (interpreter == null) {
      throw StateError(_loadError ?? kModelMissingMessage);
    }

    final output = List.filled(
      kEmbeddingLength,
      0.0,
    ).reshape([1, kEmbeddingLength]);

    await interpreter.run(face.input, output);

    final raw = <double>[];
    for (final value in output[0] as List) {
      raw.add((value as num).toDouble());
    }
    return l2Normalize(raw);
  }

  /// Dipanggil saat aplikasi ditutup. Tidak wajib di Android, tapi membuat
  /// pelepasan resource eksplisit dan mudah dijelaskan.
  Future<void> close() async {
    await _isolateInterpreter?.close();
    _interpreter?.close();
    _isolateInterpreter = null;
    _interpreter = null;
    _loadAttempted = false;
  }
}
