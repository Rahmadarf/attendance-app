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
}
