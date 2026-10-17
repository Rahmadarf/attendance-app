import 'package:attendance_app/utils/face_detection/liveness_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Waktu acuan yang tetap, supaya batas waktu bisa diuji tanpa menunggu.
final t0 = DateTime(2026, 1, 5, 8, 0, 0);

FaceSignals eyes(double openProbability) => FaceSignals(
      hasFace: true,
      eyeOpenProbability: openProbability,
      headAngleY: 0,
    );

FaceSignals head(double angle) => FaceSignals(
      hasFace: true,
      eyeOpenProbability: 1.0,
      headAngleY: angle,
    );

void main() {
  group('tantangan kedipan', () {
    LivenessSession blinkOnly() =>
        LivenessSession([LivenessChallenge.blink]);

    test('mata terbuka lalu terpejam lalu terbuka dianggap lulus', () {
      final session = blinkOnly();
      session.start(t0);

      expect(session.update(eyes(0.95), t0).status, LivenessStatus.running);
      expect(session.update(eyes(0.05), t0).status, LivenessStatus.running);

      final result = session.update(eyes(0.92), t0);
      expect(result.status, LivenessStatus.passed);
      expect(result.progress, 1.0);
    });

    test('mata terpejam terus tidak lulus — menutup celah foto mata tertutup',
        () {
      final session = blinkOnly();
      session.start(t0);

      for (var i = 0; i < 20; i++) {
        expect(session.update(eyes(0.02), t0).status, LivenessStatus.running);
      }
      expect(session.status, LivenessStatus.running);
    });

    test('mata terbuka terus tidak lulus — menutup celah foto biasa', () {
      final session = blinkOnly();
      session.start(t0);

      for (var i = 0; i < 20; i++) {
        session.update(eyes(0.99), t0);
      }
      expect(session.status, LivenessStatus.running);
    });

    test('perangkat yang tidak melaporkan peluang mata tidak membuat lulus',
        () {
      final session = blinkOnly();
      session.start(t0);

      session.update(const FaceSignals(hasFace: true), t0);
      expect(session.status, LivenessStatus.running);
    });
  });

  group('tantangan gerakan kepala', () {
    LivenessSession turnOnly() =>
        LivenessSession([LivenessChallenge.turnHead]);

    test('menoleh melewati ambang lalu kembali ke tengah dianggap lulus', () {
      final session = turnOnly();
      session.start(t0);

      session.update(head(0), t0);
      session.update(head(30), t0);
      expect(session.update(head(3), t0).status, LivenessStatus.passed);
    });

    test('arah tolehan tidak dipersoalkan, hanya besarnya', () {
      final session = turnOnly();
      session.start(t0);

      session.update(head(-28), t0);
      expect(session.update(head(0), t0).status, LivenessStatus.passed);
    });

    test('kepala miring sedikit saja belum cukup', () {
      final session = turnOnly();
      session.start(t0);

      session.update(head(15), t0);
      session.update(head(0), t0);
      expect(session.status, LivenessStatus.running);
    });

    test('menoleh tanpa kembali ke tengah belum lulus', () {
      final session = turnOnly();
      session.start(t0);

      session.update(head(40), t0);
      session.update(head(38), t0);
      expect(session.status, LivenessStatus.running);
    });
  });

  group('sesi lengkap', () {
    test('dua tantangan harus dilalui keduanya', () {
      final session = LivenessSession([
        LivenessChallenge.blink,
        LivenessChallenge.turnHead,
      ]);
      session.start(t0);

      session.update(eyes(0.95), t0);
      session.update(eyes(0.05), t0);
      final afterBlink = session.update(eyes(0.95), t0);

      // Kedipan lulus, tapi sesi belum selesai.
      expect(afterBlink.status, LivenessStatus.running);
      expect(afterBlink.progress, 0.5);
      expect(session.currentChallenge, LivenessChallenge.turnHead);

      session.update(head(30), t0);
      expect(session.update(head(0), t0).status, LivenessStatus.passed);
    });

    test('wajah hilang dari bingkai tidak memajukan progres', () {
      final session = LivenessSession([LivenessChallenge.blink]);
      session.start(t0);

      final result = session.update(const FaceSignals.noFace(), t0);
      expect(result.status, LivenessStatus.running);
      expect(result.instruction, contains('tidak terlihat'));
    });

    test('melewati batas waktu membuat sesi gagal', () {
      final session = LivenessSession([LivenessChallenge.blink]);
      session.start(t0);

      final late = t0.add(kChallengeTimeout + const Duration(seconds: 1));
      final result = session.update(eyes(0.95), late);

      expect(result.status, LivenessStatus.failed);
      expect(result.instruction, contains('Waktu habis'));
    });

    test('start mengulang sesi yang sudah gagal dari nol', () {
      final session = LivenessSession([LivenessChallenge.blink]);
      session.start(t0);
      session.update(
        eyes(0.95),
        t0.add(kChallengeTimeout + const Duration(seconds: 1)),
      );
      expect(session.status, LivenessStatus.failed);

      final restarted = session.start(t0);
      expect(restarted.status, LivenessStatus.running);
      expect(restarted.progress, 0.0);
      expect(session.currentChallenge, LivenessChallenge.blink);
    });

    test('batas waktu dihitung ulang untuk tantangan kedua', () {
      final session = LivenessSession([
        LivenessChallenge.blink,
        LivenessChallenge.turnHead,
      ]);
      session.start(t0);

      // Kedipan selesai hampir di ujung batas waktu.
      final nearLimit = t0.add(const Duration(seconds: 11));
      session.update(eyes(0.95), nearLimit);
      session.update(eyes(0.05), nearLimit);
      session.update(eyes(0.95), nearLimit);
      expect(session.currentChallenge, LivenessChallenge.turnHead);

      // Beberapa detik setelahnya masih dalam batas, karena timer direset.
      final later = nearLimit.add(const Duration(seconds: 5));
      session.update(head(30), later);
      expect(session.update(head(0), later).status, LivenessStatus.passed);
    });
  });
}
