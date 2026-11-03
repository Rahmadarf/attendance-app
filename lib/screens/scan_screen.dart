import 'package:flutter/material.dart';

import '../models/person.dart';
import '../services/face_camera.dart';
import '../services/face_config.dart';
import '../services/face_matcher.dart';
import '../widgets/face_stage.dart';

/// Recognises the person in front of the camera and pops their [Person]
/// once the same person has been seen on several polls in a row.
class ScanScreen extends StatefulWidget {
  final String title;
  final List<Person> people;

  /// Overrides for tests.
  final FaceCamera Function()? cameraFactory;
  final Duration? pollInterval;

  const ScanScreen({
    super.key,
    required this.title,
    required this.people,
    this.cameraFactory,
    this.pollInterval,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  int? _streakId;
  int _streak = 0;
  int _unknown = 0;
  bool _done = false;
  String _hint = 'Arahkan wajah ke kamera';
  Color? _color;

  void _set(String hint, {Color? color}) {
    if (hint == _hint && color == _color) return;
    setState(() {
      _hint = hint;
      _color = color;
    });
  }

  void _reset() {
    _streakId = null;
    _streak = 0;
    _unknown = 0;
  }

  void _onReading(FaceReading r) {
    if (_done) return;
    if (r.faceCount == 0) {
      _reset();
      return _set('Wajah tidak terdeteksi');
    }
    if (r.faceCount > 1) {
      _reset();
      return _set('Hanya satu wajah yang boleh terlihat');
    }
    final embedding = r.embedding;
    if (embedding == null) return _set('Mengenali…');
    if (!r.looksLive) {
      _reset();
      return _set('Gunakan wajah langsung, bukan foto atau layar');
    }

    final match = FaceMatcher.identify(embedding, widget.people);
    if (match == null) {
      _streakId = null;
      _streak = 0;
      _unknown++;
      return _set(
        _unknown >= FaceConfig.unknownFrames
            ? 'Wajah belum terdaftar. Hubungi admin.'
            : 'Mengenali…',
        color: _unknown >= FaceConfig.unknownFrames ? Colors.red : null,
      );
    }

    _unknown = 0;
    if (match.person.id == _streakId) {
      _streak++;
    } else {
      _streakId = match.person.id;
      _streak = 1;
    }
    if (_streak >= FaceConfig.stableFrames) {
      _done = true;
      Navigator.of(context).pop(match.person);
    } else {
      _set('Mengenali…');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: widget.people.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada orang terdaftar. Hubungi admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: FaceStage(
                    cameraFactory: widget.cameraFactory,
                    pollInterval: widget.pollInterval ?? FaceConfig.pollInterval,
                    onReading: _onReading,
                    hint: _hint,
                    hintColor: _color,
                  ),
                ),
              ),
      ),
    );
  }
}
