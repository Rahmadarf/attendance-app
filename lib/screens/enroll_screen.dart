import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../providers/people_provider.dart';
import '../services/face_camera.dart';
import '../services/face_config.dart';
import '../services/face_matcher.dart';
import '../widgets/face_stage.dart';

/// Registers a new person: a name plus a few face samples. Only numeric face
/// embeddings are kept, never photos. Pops `true` when saved.
class EnrollScreen extends StatefulWidget {
  /// Overrides for tests.
  final FaceCamera Function()? cameraFactory;
  final Duration? pollInterval;

  const EnrollScreen({
    super.key,
    this.cameraFactory,
    this.pollInterval,
  });

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  final _name = TextEditingController();
  final _samples = <List<double>>[];
  int _pollsSinceSample = FaceConfig.enrollGapPolls;
  bool _scanning = false;
  bool _saving = false;
  String _hint = 'Hadapkan wajah ke kamera';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _begin() {
    final name = _name.text.trim();
    if (name.isEmpty) return _message('Nama wajib diisi.');
    final taken = context
        .read<PeopleProvider>()
        .people
        .any((p) => p.name.toLowerCase() == name.toLowerCase());
    if (taken) return _message('Nama sudah terdaftar.');
    setState(() {
      _scanning = true;
      _samples.clear();
      _pollsSinceSample = FaceConfig.enrollGapPolls;
      _hint = 'Hadapkan wajah ke kamera';
    });
  }

  void _setHint(String h) {
    if (h != _hint) setState(() => _hint = h);
  }

  void _onReading(FaceReading r) {
    if (_saving) return;
    if (r.faceCount == 0) return _setHint('Wajah tidak terdeteksi');
    if (r.faceCount > 1) return _setHint('Hanya satu wajah yang boleh terlihat');
    final embedding = r.embedding;
    if (!r.looksLive) {
      return _setHint('Gunakan wajah langsung, bukan foto atau layar');
    }
    if (embedding == null || r.score < FaceConfig.enrollMinScore) {
      return _setHint('Hadapkan wajah lurus ke kamera');
    }
    if (_pollsSinceSample < FaceConfig.enrollGapPolls) {
      _pollsSinceSample++;
      return;
    }
    _pollsSinceSample = 0;
    _samples.add(embedding);
    if (_samples.length >= FaceConfig.enrollSamples) {
      _finish();
    } else {
      _setHint(
          'Sampel ${_samples.length}/${FaceConfig.enrollSamples} — gerakkan kepala sedikit');
    }
  }

  Future<void> _finish() async {
    _saving = true;
    final people = context.read<PeopleProvider>();
    final navigator = Navigator.of(context);
    String? problem;
    for (final s in _samples) {
      final m = FaceMatcher.best(s, people.people);
      if (m != null && m.similarity >= FaceConfig.matchThreshold) {
        problem = 'Wajah ini sudah terdaftar sebagai ${m.person.name}.';
        break;
      }
    }
    if (problem == null) {
      try {
        await people.add(_name.text, List.of(_samples));
        navigator.pop(true);
        return;
      } on AppException catch (e) {
        problem = e.message;
      }
    }
    if (!mounted) return;
    _message(problem);
    setState(() {
      _saving = false;
      _scanning = false;
      _samples.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah orang')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _scanning
                ? FaceStage(
                    cameraFactory: widget.cameraFactory,
                    pollInterval: widget.pollInterval ?? FaceConfig.pollInterval,
                    onReading: _onReading,
                    hint: _hint,
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _name,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: 'Nama'),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _begin(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Yang disimpan hanya data angka dari wajah, bukan foto. '
                          'Pastikan orang ini setuju wajahnya didaftarkan.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _begin,
                          child: const Text('Mulai scan wajah'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
