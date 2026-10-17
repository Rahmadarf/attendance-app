import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Wrapper tipis di atas ML Kit Face Detection agar konfigurasi detektor
/// terpusat di satu tempat.
class Vision {
  Vision._();
  static final Vision instance = Vision._();

  FaceDetector faceDetector([FaceDetectorOptions? options]) {
    return FaceDetector(
      options: options ??
          FaceDetectorOptions(
            enableClassification: true,
            enableLandmarks: true,
            performanceMode: FaceDetectorMode.accurate,
            minFaceSize: 0.15,
          ),
    );
  }

  /// Detektor terpisah untuk uji keaktifan wajah, yang memeriksa puluhan frame
  /// per detik dari stream kamera.
  ///
  /// Mode `fast` dipilih karena di sini yang dibutuhkan hanya peluang mata
  /// terbuka dan sudut kepala, bukan presisi posisi wajah. Mode `accurate`
  /// terlalu berat untuk dijalankan tiap frame dan membuat preview tersendat.
  /// Landmark dimatikan dengan alasan yang sama.
  FaceDetector livenessDetector() {
    return FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: false,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
  }
}
