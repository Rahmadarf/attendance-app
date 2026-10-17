/// Berapa lama status terbuka bertahan sebelum PIN diminta lagi.
///
/// Cukup panjang agar guru bisa mendaftarkan beberapa siswa berturut-turut
/// tanpa mengetik PIN tiap kali berpindah layar, tapi cukup pendek agar HP
/// yang ditinggal di meja tidak terus terbuka.
const Duration kAdminSessionTimeout = Duration(minutes: 10);

/// Mengingat bahwa admin sudah membuka kunci, beserta batas waktunya.
///
/// Statusnya hanya hidup di memori. Menutup aplikasi berarti terkunci lagi,
/// dan itu memang yang diinginkan.
///
/// Waktu diterima sebagai parameter, bukan dibaca dari `DateTime.now()` di
/// dalam, sehingga kedaluwarsanya bisa diuji tanpa menunggu sepuluh menit.
class AdminSession {
  AdminSession({this.timeout = kAdminSessionTimeout});

  /// Dipakai seluruh aplikasi, supaya berpindah layar tidak meminta PIN lagi.
  static final AdminSession instance = AdminSession();

  final Duration timeout;

  DateTime? _unlockedUntil;

  void unlock(DateTime now) => _unlockedUntil = now.add(timeout);

  void lock() => _unlockedUntil = null;

  bool isUnlocked(DateTime now) {
    final until = _unlockedUntil;
    if (until == null) return false;
    return now.isBefore(until);
  }

  /// Memperpanjang sesi karena admin masih aktif memakai layar.
  void touch(DateTime now) {
    if (isUnlocked(now)) unlock(now);
  }

  /// Sisa waktu sebelum terkunci sendiri, atau null bila sudah terkunci.
  Duration? remaining(DateTime now) {
    final until = _unlockedUntil;
    if (until == null || !now.isBefore(until)) return null;
    return until.difference(now);
  }
}
