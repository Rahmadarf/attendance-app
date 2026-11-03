import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors.dart';

/// Admin PIN for the management screen. This only gates the UI; it does not
/// protect data stored in the browser.
class AdminPin {
  static const maxAttempts = 5;
  static const lockDuration = Duration(seconds: 30);
  static const minLength = 4;

  static const _hashKey = 'admin_pin_hash';
  static const _saltKey = 'admin_pin_salt';
  static const _failKey = 'admin_pin_fails';
  static const _lockKey = 'admin_pin_locked_until';

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  AdminPin(this._prefs, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  bool get isSet => _prefs.getString(_hashKey) != null;

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// Time left on the lock-out, or null when not locked.
  Duration? get lockRemaining {
    final until = _prefs.getInt(_lockKey);
    if (until == null) return null;
    final left = DateTime.fromMillisecondsSinceEpoch(until).difference(_now());
    return left > Duration.zero ? left : null;
  }

  Future<void> set(String pin) async {
    if (pin.length < minLength || int.tryParse(pin) == null) {
      throw const AppException('PIN minimal 4 angka.');
    }
    final r = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
    await _prefs.setString(_saltKey, salt);
    await _prefs.setString(_hashKey, _hash(salt, pin));
    await _prefs.remove(_failKey);
    await _prefs.remove(_lockKey);
  }

  /// True if [pin] is right. Throws [AppException] while locked out.
  Future<bool> verify(String pin) async {
    final left = lockRemaining;
    if (left != null) {
      throw AppException('Terlalu banyak percobaan. Coba lagi ${left.inSeconds + 1} detik.');
    }
    final salt = _prefs.getString(_saltKey);
    final hash = _prefs.getString(_hashKey);
    if (salt != null && hash != null && _hash(salt, pin) == hash) {
      await _prefs.remove(_failKey);
      await _prefs.remove(_lockKey);
      return true;
    }
    final fails = (_prefs.getInt(_failKey) ?? 0) + 1;
    if (fails >= maxAttempts) {
      await _prefs.setInt(_failKey, 0);
      await _prefs.setInt(
          _lockKey, _now().add(lockDuration).millisecondsSinceEpoch);
    } else {
      await _prefs.setInt(_failKey, fails);
    }
    return false;
  }
}
