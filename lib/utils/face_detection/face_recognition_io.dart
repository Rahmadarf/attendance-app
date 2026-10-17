import 'package:attendance_app/utils/face_detection/camera_image_converter.dart';
import 'package:attendance_app/utils/face_detection/face_cropper.dart';
import 'package:attendance_app/utils/face_detection/face_embedder.dart';
import 'package:attendance_app/utils/face_detection/face_recognition_types.dart';
import 'package:attendance_app/utils/face_detection/google_ml_kit.dart';
import 'package:attendance_app/utils/face_detection/liveness_session.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

FaceRecognitionBackend createBackend() => NativeFaceRecognition();

/// Pengenalan wajah sungguhan untuk Android dan iOS.
///
/// Memakai Google ML Kit untuk menemukan wajah dan MobileFaceNet lewat TFLite
/// untuk menghitung embedding-nya.
class NativeFaceRecognition implements FaceRecognitionBackend {
  /// Detektor untuk foto diam: mode akurat, karena hanya dijalankan sekali per
  /// pemotretan dan hasilnya menentukan kualitas potongan wajah.
  final FaceDetector _stillDetector = GoogleMlKit.vision.faceDetector();

  /// Detektor untuk stream frame: mode cepat, karena dijalankan puluhan kali
  /// per detik dan hanya butuh peluang mata serta sudut kepala.
  final FaceDetector _streamDetector = GoogleMlKit.vision.livenessDetector();

  @override
  bool get isSimulation => false;

  @override
  String? get simulationNotice => null;

  @override
  bool get supportsLiveness => true;

  @override
  Future<String?> ensureReady() => FaceEmbedder.instance.ensureReady();

  @override
  Future<FaceScanOutcome> scan(XFile file) async {
    final List<Face> faces;
    try {
      faces = await _stillDetector.processImage(
        InputImage.fromFilePath(file.path),
      );
    } catch (e) {
      return FaceScanOutcome.failure("Gagal memproses deteksi wajah: $e");
    }

    if (faces.isEmpty) {
      return const FaceScanOutcome.failure(
        "Wajah tidak terdeteksi! Pastikan wajah terlihat jelas di bingkai.",
      );
    }

    // Bila ada beberapa wajah di frame, ambil yang paling besar — itu yang
    // paling dekat ke kamera, jadi paling mungkin orang yang sedang absen.
    final face = faces.reduce((a, b) {
      final areaA = a.boundingBox.width * a.boundingBox.height;
      final areaB = b.boundingBox.width * b.boundingBox.height;
      return areaA >= areaB ? a : b;
    });

    final bytes = await file.readAsBytes();
    final cropped = cropFaceForEmbedding(bytes, face.boundingBox);
    if (cropped == null) {
      return const FaceScanOutcome.failure(
        "Foto tidak bisa dibaca. Coba ambil ulang.",
      );
    }

    final modelError = await FaceEmbedder.instance.ensureReady();
    if (modelError != null) return FaceScanOutcome.failure(modelError);

    try {
      final embedding = await FaceEmbedder.instance.embed(cropped);
      return FaceScanOutcome(
        embedding: embedding,
        thumbnailJpg: cropped.thumbnailJpg,
        headEulerAngleY: face.headEulerAngleY,
      );
    } catch (e) {
      return FaceScanOutcome.failure("Gagal menghitung ciri wajah: $e");
    }
  }

  @override
  Future<FaceSignals?> analyzeFrame({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation orientation,
  }) async {
    final inputImage = inputImageFromCameraImage(
      image: image,
      camera: camera,
      deviceOrientation: orientation,
    );
    if (inputImage == null) return null;

    final faces = await _streamDetector.processImage(inputImage);
    return toFaceSignals(faces);
  }

  @override
  void dispose() {
    _stillDetector.close();
    _streamDetector.close();
  }
}
