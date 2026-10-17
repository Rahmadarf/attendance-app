import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Panjang PIN admin.
const int kAdminPinLength = 6;

/// Berapa kali hash diulang.
///
/// PIN enam digit hanya punya satu juta kemungkinan, jadi satu kali SHA-256
/// terlalu cepat ditebak habis. Mengulang hash membuat setiap percobaan jauh
/// lebih mahal tanpa terasa lambat bagi pengguna yang hanya menebak sekali.
const int kPinHashIterations = 50000;

/// True bila [pin] berupa enam digit angka.
bool isValidPinFormat(String pin) {
  if (pin.length != kAdminPinLength) return false;
  return RegExp(r'^\d+$').hasMatch(pin);
}

/// Membuat salt acak dalam bentuk heksadesimal.
///
/// Salt membuat dua sekolah yang kebetulan memakai PIN sama menghasilkan hash
/// berbeda, sehingga tabel tebakan yang sudah jadi tidak bisa dipakai ulang.
String generateSalt([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Menghitung hash PIN yang disimpan ke database.
///
/// PIN aslinya tidak pernah ditulis ke mana pun — yang tersimpan hanya hasil
/// hash beserta salt-nya.
String hashPin(String pin, String salt) {
  var digest = sha256.convert(utf8.encode('$salt:$pin')).bytes;
  for (var i = 1; i < kPinHashIterations; i++) {
    digest = sha256.convert(digest).bytes;
  }
  return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Membandingkan PIN yang diketik dengan hash yang tersimpan.
bool verifyPin({
  required String pin,
  required String salt,
  required String expectedHash,
}) {
  if (!isValidPinFormat(pin)) return false;
  return _constantTimeEquals(hashPin(pin, salt), expectedHash);
}

/// Perbandingan yang selalu memeriksa seluruh karakter.
///
/// Operator `==` pada String berhenti di karakter pertama yang berbeda,
/// sehingga lama perbandingannya membocorkan seberapa banyak awalan yang sudah
/// benar. Di sini setiap karakter selalu diperiksa agar waktunya seragam.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}
