import 'package:attendance_app/services/face_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  group('similarity', () {
    test('identical vectors score 1, empty or mismatched score 0', () {
      expect(FaceMatcher.similarity(embed(0), embed(0)), 1);
      expect(FaceMatcher.similarity([], []), 0);
      expect(FaceMatcher.similarity([1], [1, 2]), 0);
    });

    test('matches Human formula on known values', () {
      // dist=25*sum. sum=0.0025 -> dist=0.0625 -> norm=(1-0.0025-0.2)/0.6>1.
      expect(FaceMatcher.similarity([0.1, 0.2, 0.3], [0.1, 0.2, 0.35]), 1.0);
      // sum=4 -> dist=100 -> root=10 -> (1-0.1-0.2)/0.6 = 1.1667 -> clamp 1.
      // sum=100 -> dist=2500 -> root=50 -> (1-0.5-0.2)/0.6 = 0.5.
      expect(FaceMatcher.similarity([10.0], [0.0]), closeTo(0.5, 1e-9));
      // Far apart -> clamped to 0.
      expect(FaceMatcher.similarity([100.0], [0.0]), 0.0);
    });
  });

  group('identify', () {
    final ana = person(1, 'Ana', [embed(0), embed(0, jitter: 0.05)]);
    final budi = person(2, 'Budi', [embed(3)]);

    test('finds the right person, using the best of several samples', () {
      final m = FaceMatcher.identify(embed(0, jitter: 0.02), [ana, budi]);
      expect(m?.person.id, 1);
      expect(m!.similarity, greaterThan(m.runnerUp));
    });

    test('unknown face is rejected', () {
      expect(FaceMatcher.identify(embed(6), [ana, budi]), isNull);
    });

    test('no one registered -> null', () {
      expect(FaceMatcher.identify(embed(0), []), isNull);
      expect(FaceMatcher.best(embed(0), []), isNull);
    });

    test('ambiguous between two people is rejected', () {
      final twin = person(3, 'Ana2', [embed(0, jitter: 0.001)]);
      expect(FaceMatcher.identify(embed(0), [ana, twin]), isNull);
    });
  });
}
