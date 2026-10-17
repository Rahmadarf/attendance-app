import 'package:attendance_app/utils/admin_pin.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// PIN admin yang tersimpan: hash beserta salt-nya, tanpa PIN aslinya.
class AdminCredential {
  final String salt;
  final String hash;

  const AdminCredential({required this.salt, required this.hash});

  bool matches(String pin) =>
      verifyPin(pin: pin, salt: salt, expectedHash: hash);
}

/// Akses ke dokumen `settings/admin` di Firestore.
///
/// Disimpan di cloud, bukan di perangkat, supaya PIN yang dibuat guru di satu
/// HP tetap berlaku di HP lain yang memakai aplikasi ini.
class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore})
      : _doc = (firestore ?? FirebaseFirestore.instance)
            .collection('settings')
            .doc('admin');

  final DocumentReference _doc;

  /// Mengembalikan null bila PIN belum pernah dibuat sama sekali.
  Future<AdminCredential?> fetch() async {
    final snapshot = await _doc.get();
    if (!snapshot.exists) return null;

    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final salt = data['pin_salt']?.toString() ?? '';
    final hash = data['pin_hash']?.toString() ?? '';
    if (salt.isEmpty || hash.isEmpty) return null;

    return AdminCredential(salt: salt, hash: hash);
  }

  /// Menyimpan PIN baru. PIN aslinya tidak ikut tertulis.
  Future<void> setPin(String pin) async {
    final salt = generateSalt();
    await _doc.set({
      'pin_salt': salt,
      'pin_hash': hashPin(pin, salt),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
