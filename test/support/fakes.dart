import 'package:attendance_app/models/person.dart';
import 'package:attendance_app/services/face_camera.dart';
import 'package:flutter/material.dart';

/// Camera that replays [readings] one per poll; the last one repeats.
class FakeCamera implements FaceCamera {
  final List<FaceReading> readings;
  final FaceCameraException? failure;
  int polls = 0;
  bool disposed = false;

  FakeCamera(this.readings, {this.failure});

  @override
  Future<void> start() async {
    if (failure != null) throw failure!;
  }

  @override
  Widget buildView() => const ColoredBox(color: Colors.black);

  @override
  Future<FaceReading?> analyze() async =>
      readings[polls < readings.length ? polls++ : readings.length - 1];

  @override
  Future<void> dispose() async => disposed = true;
}

/// Deterministic 8-d "embedding" pointing along axis [axis]. Scaled so that
/// different axes score well below the match threshold under Human's
/// similarity formula, while the same axis with a small [jitter] scores ~1.
List<double> embed(int axis, {double jitter = 0}) => List.generate(
    8,
    (i) =>
        10 * ((i == axis ? 1.0 : 0.0) + (i == (axis + 1) % 8 ? jitter : 0)));

FaceReading face(List<double> e,
        {double score = 0.95, double real = 0.9, double live = 0.9}) =>
    FaceReading(
        faceCount: 1, embedding: e, score: score, real: real, live: live);

Person person(int id, String name, List<List<double>> faces) =>
    Person(id: id, name: name, faces: faces);
