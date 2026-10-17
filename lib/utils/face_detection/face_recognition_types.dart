import 'dart:typed_data';

import 'package:attendance_app/utils/face_detection/liveness_session.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

/// Hasil satu kali pemindaian wajah, dari foto sampai embedding.
class FaceScanOutcome {
  /// Embedding wajah yang sudah dinormalisasi, null bila gagal.
  final List<double>? embedding;

  /// Potongan wajah 112x112 sebagai JPEG, dipakai sebagai foto siswa.
  final Uint8List? thumbnailJpg;

  /// Sudut putar kepala kiri/kanan dari ML Kit. Null di mode simulasi.
  final double? headEulerAngleY;

  /// Pesan siap tampil bila ada yang gagal, null bila berhasil.
  final String? error;

  const FaceScanOutcome({
    this.embedding,
    this.thumbnailJpg,
    this.headEulerAngleY,
    this.error,
  });

  const FaceScanOutcome.failure(String message) : this(error: message);

  bool get isSuccess => embedding != null;
}

/// Lapisan pengenalan wajah, dengan satu implementasi per platform.
///
/// Kenapa dipisah begini: `tflite_flutter` memanggil kode native lewat
/// `dart:ffi`, dan `dart:ffi` tidak ada di browser — kehadirannya saja sudah
/// menggagalkan kompilasi web. Google ML Kit juga tidak punya implementasi web
/// maupun macOS. Jadi seluruh bagian yang bergantung pada keduanya dikurung di
/// balik antarmuka ini, lalu dipilih lewat conditional import pada
/// `face_recognition.dart`.
///
/// Akibatnya tidak ada tipe milik ML Kit atau `dart:io` yang menembus sampai
/// lapisan UI. Layar-layar presensi memanggil antarmuka ini saja, sehingga satu
/// kode UI melayani aplikasi Android sungguhan maupun mode simulasi di Chrome.
abstract class FaceRecognitionBackend {
  /// True bila ini bukan pengenalan wajah sungguhan, melainkan pengganti untuk
  /// pengembangan. UI wajib menampilkan penanda saat ini bernilai true.
  bool get isSimulation;

  /// Penjelasan singkat untuk ditampilkan di banner mode simulasi.
  String? get simulationNotice;

  /// True bila uji keaktifan wajah betul-betul bisa dijalankan. False di mode
  /// simulasi, karena menilai kedipan butuh ML Kit.
  bool get supportsLiveness;

  /// Memuat model bila perlu. Mengembalikan null bila siap, atau pesan
  /// kesalahan yang siap ditampilkan.
  Future<String?> ensureReady();

  /// Memproses satu foto menjadi embedding wajah.
  Future<FaceScanOutcome> scan(XFile file);

  /// Membaca isyarat wajah dari satu frame stream kamera, untuk uji keaktifan.
  /// Mengembalikan null bila frame dilewati atau platform tidak mendukungnya.
  Future<FaceSignals?> analyzeFrame({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation orientation,
  });

  /// Melepas detektor dan model.
  void dispose();
}
