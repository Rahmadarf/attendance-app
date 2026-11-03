import 'package:flutter/widgets.dart';

import 'face_camera.dart';

FaceCamera createFaceCamera() => _UnsupportedFaceCamera();

/// Used outside the browser (e.g. VM tests), where there is no camera.
class _UnsupportedFaceCamera implements FaceCamera {
  @override
  Future<void> start() =>
      Future.error(const FaceCameraException('Kamera hanya didukung di browser.'));

  @override
  Widget buildView() => const SizedBox.shrink();

  @override
  Future<FaceReading?> analyze() async => null;

  @override
  Future<void> dispose() async {}
}
