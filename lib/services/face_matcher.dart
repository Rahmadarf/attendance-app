import 'dart:math';

import '../models/person.dart';
import 'face_config.dart';

class FaceMatch {
  final Person person;
  final double similarity;

  /// Best similarity among *other* people (0 if there are none).
  final double runnerUp;

  const FaceMatch(this.person, this.similarity, this.runnerUp);
}

class FaceMatcher {
  const FaceMatcher._();

  /// Same formula as Human's `human.match.similarity` (order 2, multiplier 25,
  /// min 0.2, max 0.8), without its rounding.
  static double similarity(List<double> a, List<double> b) {
    if (a.isEmpty || a.length != b.length) return 0;
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    final dist = 25 * sum;
    if (dist == 0) return 1;
    final norm = (1 - sqrt(dist) / 100 - 0.2) / (0.8 - 0.2);
    return norm.clamp(0.0, 1.0);
  }

  /// Closest registered person, whatever the score; null if nobody is registered.
  static FaceMatch? best(List<double> embedding, List<Person> people) {
    Person? top;
    var topSim = -1.0;
    var second = 0.0;
    for (final p in people) {
      var s = 0.0;
      for (final f in p.faces) {
        s = max(s, similarity(embedding, f));
      }
      if (s > topSim) {
        if (top != null) second = max(second, topSim);
        top = p;
        topSim = s;
      } else {
        second = max(second, s);
      }
    }
    return top == null ? null : FaceMatch(top, topSim, second);
  }

  /// The person this face belongs to, or null if unknown or ambiguous.
  static FaceMatch? identify(
    List<double> embedding,
    List<Person> people, {
    double threshold = FaceConfig.matchThreshold,
    double margin = FaceConfig.matchMargin,
  }) {
    final m = best(embedding, people);
    if (m == null) return null;
    if (m.similarity < threshold) return null;
    if (m.similarity - m.runnerUp < margin) return null;
    return m;
  }
}
