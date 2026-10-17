/// Pintu masuk lapisan pengenalan wajah.
///
/// Implementasinya dipilih saat kompilasi:
///
/// - Android dan iOS mendapat `face_recognition_io.dart`, yang memakai Google
///   ML Kit dan MobileFaceNet sungguhan.
/// - Web mendapat `face_recognition_web.dart`, mode simulasi, karena
///   `dart:ffi` tidak ada di browser dan ML Kit tidak punya versi web.
///
/// Karena pemilihannya di tingkat import, `tflite_flutter` tidak pernah ikut
/// terkompilasi untuk web — itu syaratnya agar `flutter build web` berhasil.
library;

import 'package:attendance_app/utils/face_detection/face_recognition_types.dart';
import 'package:attendance_app/utils/face_detection/face_recognition_web.dart'
    if (dart.library.io) 'package:attendance_app/utils/face_detection/face_recognition_io.dart'
    as impl;

export 'package:attendance_app/utils/face_detection/face_recognition_types.dart';

/// Membuat backend yang sesuai untuk platform tempat aplikasi berjalan.
FaceRecognitionBackend createFaceRecognitionBackend() =>
    impl.createBackend();
