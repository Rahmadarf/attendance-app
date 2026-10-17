import 'dart:io';
import 'dart:ui' show Size;

import 'package:attendance_app/utils/face_detection/liveness_session.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Derajat rotasi tampilan untuk tiap orientasi perangkat.
const Map<DeviceOrientation, int> _orientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Mengubah satu frame dari `startImageStream` menjadi [InputImage] untuk ML Kit.
///
/// Dibutuhkan karena uji keaktifan wajah menilai gerakan antar frame, sedangkan
/// `takePicture()` hanya memberi satu foto diam. Stream frame tidak berbentuk
/// JPEG, jadi harus dibungkus sendiri beserta metadata ukuran, format, dan
/// rotasinya.
///
/// Mengembalikan null bila format atau orientasi tidak dikenali — pemanggil
/// cukup melewati frame itu, bukan menggagalkan sesi.
InputImage? inputImageFromCameraImage({
  required CameraImage image,
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
}) {
  final rotation = _resolveRotation(camera, deviceOrientation);
  if (rotation == null) return null;

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  // ML Kit hanya menerima nv21 di Android dan bgra8888 di iOS. Keduanya
  // berupa satu bidang (plane) data, berbeda dari yuv420 yang terpisah tiga.
  if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
  if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
  if (image.planes.length != 1) return null;

  final plane = image.planes.first;

  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

/// Menghitung rotasi yang harus dilaporkan ke ML Kit.
///
/// Tanpa rotasi yang benar, ML Kit mencari wajah pada citra yang miring dan
/// sering tidak menemukan apa pun. Di iOS orientasi sensor sudah cukup. Di
/// Android, orientasi sensor harus dikompensasi dengan orientasi perangkat,
/// dan arah kompensasinya berbeda antara kamera depan dan belakang karena
/// citra kamera depan tercermin.
InputImageRotation? _resolveRotation(
  CameraDescription camera,
  DeviceOrientation deviceOrientation,
) {
  if (Platform.isIOS) {
    return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
  }

  if (!Platform.isAndroid) return null;

  final deviceDegrees = _orientationDegrees[deviceOrientation];
  if (deviceDegrees == null) return null;

  final compensated = camera.lensDirection == CameraLensDirection.front
      ? (camera.sensorOrientation + deviceDegrees) % 360
      : (camera.sensorOrientation - deviceDegrees + 360) % 360;

  return InputImageRotationValue.fromRawValue(compensated);
}

/// Mengambil isyarat yang dipakai uji keaktifan dari wajah terbesar di frame.
///
/// Peluang mata kiri dan kanan dirata-ratakan: kedipan sejati menutup kedua
/// mata, sedangkan satu mata yang tertutup bisa jadi hanya kesalahan deteksi.
FaceSignals toFaceSignals(List<Face> faces) {
  if (faces.isEmpty) return const FaceSignals.noFace();

  final face = faces.reduce((a, b) {
    final areaA = a.boundingBox.width * a.boundingBox.height;
    final areaB = b.boundingBox.width * b.boundingBox.height;
    return areaA >= areaB ? a : b;
  });

  final left = face.leftEyeOpenProbability;
  final right = face.rightEyeOpenProbability;

  double? eyeOpen;
  if (left != null && right != null) {
    eyeOpen = (left + right) / 2;
  } else {
    eyeOpen = left ?? right;
  }

  return FaceSignals(
    hasFace: true,
    eyeOpenProbability: eyeOpen,
    headAngleY: face.headEulerAngleY,
  );
}
