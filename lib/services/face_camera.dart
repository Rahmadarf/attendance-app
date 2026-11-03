import 'package:flutter/widgets.dart';

import 'face_config.dart';

/// Thrown by [FaceCamera.start] with a message that is safe to show.
class FaceCameraException implements Exception {
  final String message;
  const FaceCameraException(this.message);

  @override
  String toString() => message;
}

/// One analysed camera frame.
class FaceReading {
  final int faceCount;

  /// Face embedding; only set when exactly one face is in view.
  final List<double>? embedding;

  /// Detector confidence for the single face (0..1).
  final double score;

  /// Anti-spoof scores (0..1); null when the model did not report one.
  final double? real;
  final double? live;

  const FaceReading({
    required this.faceCount,
    this.embedding,
    this.score = 0,
    this.real,
    this.live,
  });

  const FaceReading.none() : this(faceCount: 0);

  /// False when the face looks like a photo or a screen.
  bool get looksLive =>
      (real ?? 1) >= FaceConfig.minReal && (live ?? 1) >= FaceConfig.minLive;
}

/// Live camera plus on-device face analysis. Frames stay in memory; nothing is
/// saved or uploaded.
abstract class FaceCamera {
  /// Opens the camera and loads the models.
  Future<void> start();

  /// Live preview. Only valid after [start] completed.
  Widget buildView();

  /// Analyses the current frame, or null if no frame is ready yet.
  Future<FaceReading?> analyze();

  Future<void> dispose();
}
