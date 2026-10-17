import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:attendance_app/utils/face_detection/face_model_spec.dart';
import 'package:image/image.dart' as img;

/// Hasil pemotongan wajah: tensor siap pakai dan thumbnail untuk ditampilkan.
class CroppedFace {
  /// Tensor `[1, 112, 112, 3]` float32 dengan nilai di rentang [-1, 1].
  final List<List<List<List<double>>>> input;

  /// Potongan wajah 112x112 sebagai JPEG, dipakai sebagai foto siswa.
  final Uint8List thumbnailJpg;

  const CroppedFace({required this.input, required this.thumbnailJpg});
}

/// Memotong area wajah dari foto selfie lalu mengubahnya ke bentuk yang
/// dimengerti model.
///
/// [jpegBytes] adalah isi file hasil `CameraController.takePicture()`, dan
/// [boundingBox] adalah `Face.boundingBox` dari ML Kit.
///
/// Mengembalikan null bila gambar gagal didekode.
CroppedFace? cropFaceForEmbedding(Uint8List jpegBytes, Rect boundingBox) {
  final decoded = img.decodeImage(jpegBytes);
  if (decoded == null) return null;

  // Terapkan rotasi EXIF. Tanpa ini, foto dari sebagian perangkat Android
  // masuk ke model dalam keadaan miring 90 derajat dan skor kemiripannya
  // selalu rendah tanpa sebab yang kelihatan.
  final oriented = img.bakeOrientation(decoded);

  final marginX = boundingBox.width * kFaceCropMargin;
  final marginY = boundingBox.height * kFaceCropMargin;

  // Bounding box bisa menjorok keluar frame saat wajah berada di tepi, jadi
  // setiap sisi dijepit ke batas gambar.
  final left = (boundingBox.left - marginX).round().clamp(0, oriented.width - 1);
  final top = (boundingBox.top - marginY).round().clamp(0, oriented.height - 1);
  final right =
      (boundingBox.right + marginX).round().clamp(left + 1, oriented.width);
  final bottom =
      (boundingBox.bottom + marginY).round().clamp(top + 1, oriented.height);

  final cropped = img.copyCrop(
    oriented,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );

  final resized = img.copyResize(
    cropped,
    width: kFaceInputSize,
    height: kFaceInputSize,
    interpolation: img.Interpolation.linear,
  );

  return CroppedFace(
    input: _toNormalizedTensor(resized),
    thumbnailJpg: Uint8List.fromList(img.encodeJpg(resized, quality: 85)),
  );
}

/// Mengubah citra 112x112 menjadi tensor `[1, 112, 112, 3]` dengan skala
/// [-1, 1], sesuai praktik standar MobileFaceNet: `(piksel - 127.5) / 128`.
List<List<List<List<double>>>> _toNormalizedTensor(img.Image image) {
  final rows = <List<List<double>>>[];

  for (var y = 0; y < kFaceInputSize; y++) {
    final row = <List<double>>[];
    for (var x = 0; x < kFaceInputSize; x++) {
      final pixel = image.getPixel(x, y);
      row.add([
        (pixel.r - 127.5) / 128.0,
        (pixel.g - 127.5) / 128.0,
        (pixel.b - 127.5) / 128.0,
      ]);
    }
    rows.add(row);
  }

  return [rows];
}
