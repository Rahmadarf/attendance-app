import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'face_camera.dart';

// Human (face detection + embedding + anti-spoof), loaded on demand from a CDN
// so index.html stays untouched. Its models are served from the same package.
const _version = '3.3.6';
const _base = 'https://cdn.jsdelivr.net/npm/@vladmandic/human@$_version';
const _bundleUrl = '$_base/dist/human.esm.js';
const _modelsUrl = '$_base/models/';

FaceCamera createFaceCamera() => _WebFaceCamera();

class _WebFaceCamera implements FaceCamera {
  static int _counter = 0;

  final String _viewType = 'face-camera-${_counter++}';
  final web.HTMLVideoElement _video = web.HTMLVideoElement();
  web.MediaStream? _stream;
  JSObject? _human;
  bool _disposed = false;

  _WebFaceCamera() {
    _video
      ..autoplay = true
      ..muted = true
      ..playsInline = true;
    _video.style
      ..width = '100%'
      ..height = '100%'
      ..setProperty('object-fit', 'cover')
      ..setProperty('transform', 'scaleX(-1)'); // mirror like a selfie
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _video);
  }

  @override
  Future<void> start() async {
    await _openCamera();
    if (_disposed) return;
    await _loadModels();
  }

  Future<void> _openCamera() async {
    final devices = web.window.navigator.mediaDevices;
    try {
      final stream = await devices
          .getUserMedia(web.MediaStreamConstraints(
            video: {'facingMode': 'user'}.jsify()!,
          ))
          .toDart;
      if (_disposed) {
        _stop(stream);
        return;
      }
      _stream = stream;
      _video.srcObject = stream;
      await _video.play().toDart;
    } catch (e) {
      final s = e.toString();
      if (s.contains('NotAllowedError') || s.contains('SecurityError')) {
        throw const FaceCameraException(
            'Izin kamera ditolak. Klik ikon kamera di address bar Chrome, lalu izinkan.');
      }
      if (s.contains('NotFoundError') || s.contains('OverconstrainedError')) {
        throw const FaceCameraException('Kamera tidak ditemukan di perangkat ini.');
      }
      if (s.contains('NotReadableError')) {
        throw const FaceCameraException(
            'Kamera sedang dipakai aplikasi lain. Tutup lalu coba lagi.');
      }
      throw FaceCameraException('Kamera tidak bisa dibuka ($s).');
    }
  }

  Future<void> _loadModels() async {
    try {
      final module = await importModule(_bundleUrl.toJS).toDart;
      // Caching is off (skipFrames/skipTime 0, cacheSensitivity 0): Human
      // otherwise reuses the previous embedding for several seconds, which
      // would attribute a new person's face to the one before.
      const off = {'skipFrames': 0, 'skipTime': 0};
      final config = {
        'backend': 'webgl',
        'modelBasePath': _modelsUrl,
        'debug': false,
        'warmup': 'face',
        'cacheSensitivity': 0,
        'face': {
          'enabled': true,
          'detector': {'rotation': false, 'maxDetected': 2, ...off},
          'mesh': {'enabled': true},
          'iris': {'enabled': false},
          'emotion': {'enabled': false},
          'description': {'enabled': true, ...off},
          'antispoof': {'enabled': true, ...off},
          'liveness': {'enabled': true, ...off},
        },
        'body': {'enabled': false},
        'hand': {'enabled': false},
        'object': {'enabled': false},
        'gesture': {'enabled': false},
        'segmentation': {'enabled': false},
      }.jsify();
      final human = module
          .getProperty<JSFunction>('Human'.toJS)
          .callAsConstructor<JSObject>(config);
      await human.callMethod<JSPromise<JSAny?>>('load'.toJS).toDart;
      await human.callMethod<JSPromise<JSAny?>>('warmup'.toJS).toDart;
      if (_disposed) return;
      _human = human;
    } catch (_) {
      throw const FaceCameraException(
          'Butuh internet untuk memuat model pengenalan wajah. Periksa koneksi lalu coba lagi.');
    }
  }

  @override
  Widget buildView() => HtmlElementView(viewType: _viewType);

  @override
  Future<FaceReading?> analyze() async {
    final human = _human;
    // readyState 2 = HAVE_CURRENT_DATA: a frame is available.
    if (human == null || _disposed || _video.readyState < 2 || _video.videoWidth == 0) {
      return null;
    }
    final result = await human
        .callMethod<JSPromise<JSObject>>('detect'.toJS, _video)
        .toDart;
    if (_disposed) return null;
    final faces = result.getProperty<JSArray<JSObject>>('face'.toJS).toDart;
    if (faces.length != 1) return FaceReading(faceCount: faces.length);
    final face = faces.first;

    double? number(String key) {
      final v = face.getProperty<JSAny?>(key.toJS);
      return v.isA<JSNumber>() ? (v as JSNumber).toDartDouble : null;
    }

    final emb = face.getProperty<JSAny?>('embedding'.toJS);
    final embedding = emb.isA<JSArray<JSAny?>>()
        ? (emb as JSArray<JSAny?>)
            .toDart
            .map((n) => (n as JSNumber).toDartDouble)
            .toList()
        : null;
    return FaceReading(
      faceCount: 1,
      embedding: embedding,
      score: number('score') ?? 0,
      real: number('real'),
      live: number('live'),
    );
  }

  void _stop(web.MediaStream stream) {
    for (final t in stream.getTracks().toDart) {
      t.stop();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final s = _stream;
    _stream = null;
    if (s != null) _stop(s);
    _video.srcObject = null;
    _human = null;
  }
}
