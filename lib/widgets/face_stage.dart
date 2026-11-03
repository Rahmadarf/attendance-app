import 'dart:async';

import 'package:flutter/material.dart';

import '../services/face_camera.dart';
import '../services/face_camera_factory.dart';
import '../services/face_config.dart';

/// Camera preview that polls [FaceCamera.analyze] and hands each reading to
/// [onReading]. Owns the camera lifecycle, loading and error states; the parent
/// decides what the readings mean and sets [hint].
class FaceStage extends StatefulWidget {
  final void Function(FaceReading reading) onReading;
  final String hint;
  final Color? hintColor;
  final Widget? bottom;

  /// Overrides for tests; default to the browser camera.
  final FaceCamera Function()? cameraFactory;
  final Duration pollInterval;

  const FaceStage({
    super.key,
    required this.onReading,
    required this.hint,
    this.hintColor,
    this.bottom,
    this.cameraFactory,
    this.pollInterval = FaceConfig.pollInterval,
  });

  @override
  State<FaceStage> createState() => _FaceStageState();
}

class _FaceStageState extends State<FaceStage> {
  late final FaceCamera _camera = (widget.cameraFactory ?? createFaceCamera)();
  Timer? _timer;
  bool _started = false;
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _camera.start();
    } on FaceCameraException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _started = true);
    _timer = Timer.periodic(widget.pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      final reading = await _camera.analyze();
      if (reading != null && mounted) widget.onReading(reading);
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: !_started
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Menyiapkan kamera…'),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _camera.buildView(),
                  ),
                ),
        ),
        if (_started)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: widget.hintColor ?? scheme.onSurface,
              ),
            ),
          ),
        if (widget.bottom != null)
          Padding(padding: const EdgeInsets.all(16), child: widget.bottom),
        const SizedBox(height: 16),
      ],
    );
  }
}
