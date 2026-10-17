import 'dart:math';

import 'package:attendance_app/services/admin_session.dart';
import 'package:attendance_app/utils/admin_pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidPinFormat', () {
    test('enam digit angka diterima', () {
      expect(isValidPinFormat('123456'), isTrue);
      expect(isValidPinFormat('000000'), isTrue);
    });

    test('panjang selain enam ditolak', () {
      expect(isValidPinFormat('12345'), isFalse);
      expect(isValidPinFormat('1234567'), isFalse);
      expect(isValidPinFormat(''), isFalse);
    });

    test('bukan angka ditolak', () {
      expect(isValidPinFormat('12345a'), isFalse);
      expect(isValidPinFormat('12 456'), isFalse);
      expect(isValidPinFormat('１２３４５６'), isFalse);
    });
  });

  group('generateSalt', () {
    test('menghasilkan 32 karakter heksadesimal', () {
      final salt = generateSalt(Random(1));
      expect(salt.length, 32);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(salt), isTrue);
    });

    test('dua salt berturut-turut berbeda', () {
      expect(generateSalt(), isNot(generateSalt()));
    });
  });

  group('hashPin', () {
    test('PIN sama dengan salt sama menghasilkan hash sama', () {
      expect(hashPin('123456', 'abc'), hashPin('123456', 'abc'));
    });

    test('salt berbeda menghasilkan hash berbeda untuk PIN yang sama', () {
      expect(hashPin('123456', 'abc'), isNot(hashPin('123456', 'xyz')));
    });

    test('PIN berbeda menghasilkan hash berbeda', () {
      expect(hashPin('123456', 'abc'), isNot(hashPin('123457', 'abc')));
    });

    test('hash tidak memuat PIN aslinya', () {
      expect(hashPin('123456', 'abc'), isNot(contains('123456')));
    });
  });

  group('verifyPin', () {
    const salt = 'a1b2c3';
    final hash = hashPin('135790', salt);

    test('PIN benar diterima', () {
      expect(verifyPin(pin: '135790', salt: salt, expectedHash: hash), isTrue);
    });

    test('PIN salah ditolak', () {
      expect(verifyPin(pin: '135791', salt: salt, expectedHash: hash), isFalse);
    });

    test('PIN dengan format tidak sah langsung ditolak', () {
      expect(verifyPin(pin: 'abcdef', salt: salt, expectedHash: hash), isFalse);
      expect(verifyPin(pin: '1357', salt: salt, expectedHash: hash), isFalse);
    });

    test('salt yang salah membuat PIN benar pun ditolak', () {
      expect(
        verifyPin(pin: '135790', salt: 'salt-lain', expectedHash: hash),
        isFalse,
      );
    });
  });

  group('AdminSession', () {
    final t0 = DateTime(2026, 1, 5, 8, 0);

    test('awalnya terkunci', () {
      expect(AdminSession().isUnlocked(t0), isFalse);
    });

    test('terbuka setelah unlock, dan masih terbuka sebelum batas waktu', () {
      final session = AdminSession(timeout: const Duration(minutes: 10));
      session.unlock(t0);

      expect(session.isUnlocked(t0), isTrue);
      expect(session.isUnlocked(t0.add(const Duration(minutes: 9))), isTrue);
    });

    test('terkunci sendiri setelah batas waktu lewat', () {
      final session = AdminSession(timeout: const Duration(minutes: 10));
      session.unlock(t0);

      expect(session.isUnlocked(t0.add(const Duration(minutes: 10))), isFalse);
      expect(session.isUnlocked(t0.add(const Duration(minutes: 11))), isFalse);
    });

    test('lock mengunci seketika walau batas waktu belum lewat', () {
      final session = AdminSession(timeout: const Duration(minutes: 10));
      session.unlock(t0);
      session.lock();

      expect(session.isUnlocked(t0), isFalse);
    });

    test('touch memperpanjang sesi yang masih terbuka', () {
      final session = AdminSession(timeout: const Duration(minutes: 10));
      session.unlock(t0);

      final later = t0.add(const Duration(minutes: 9));
      session.touch(later);

      // Tanpa touch, pukul 08.10 sudah terkunci.
      expect(session.isUnlocked(t0.add(const Duration(minutes: 15))), isTrue);
    });

    test('touch tidak membuka sesi yang sudah terkunci', () {
      final session = AdminSession(timeout: const Duration(minutes: 10));
      session.unlock(t0);

      final afterTimeout = t0.add(const Duration(minutes: 20));
      session.touch(afterTimeout);

      expect(session.isUnlocked(afterTimeout), isFalse);
    });

    test('remaining menghitung sisa waktu, null bila terkunci', () {
      final session = AdminSession(timeout: const Duration(minutes: 10));
      expect(session.remaining(t0), isNull);

      session.unlock(t0);
      expect(
        session.remaining(t0.add(const Duration(minutes: 4))),
        const Duration(minutes: 6),
      );
      expect(session.remaining(t0.add(const Duration(minutes: 30))), isNull);
    });
  });
}
