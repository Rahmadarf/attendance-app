import 'dart:math';

/// Ambang mata dianggap terbuka.
const double kEyeOpenThreshold = 0.70;

/// Ambang mata dianggap terpejam.
const double kEyeClosedThreshold = 0.20;

/// Besar sudut putar kepala yang harus dicapai, dalam derajat.
const double kHeadTurnThreshold = 22.0;

/// Batas sudut agar kepala dianggap kembali menghadap depan.
const double kHeadCenterThreshold = 10.0;

/// Waktu maksimal untuk menyelesaikan satu tantangan.
const Duration kChallengeTimeout = Duration(seconds: 12);

/// Isyarat wajah yang diambil dari satu frame kamera.
///
/// Sengaja berupa tipe sendiri, bukan `Face` milik ML Kit, supaya logika
/// liveness bisa diuji tanpa kamera maupun plugin native.
class FaceSignals {
  final bool hasFace;

  /// Rata-rata peluang kedua mata terbuka, 0 sampai 1. Null bila perangkat
  /// tidak melaporkannya.
  final double? eyeOpenProbability;

  /// Sudut putar kepala kiri/kanan dalam derajat. Null bila tidak dilaporkan.
  final double? headAngleY;

  const FaceSignals({
    required this.hasFace,
    this.eyeOpenProbability,
    this.headAngleY,
  });

  const FaceSignals.noFace() : this(hasFace: false);
}

/// Tantangan yang harus dilakukan pengguna untuk membuktikan dia orang hidup.
enum LivenessChallenge {
  blink('Kedipkan mata Anda'),
  turnHead('Putar kepala ke samping, lalu hadap depan lagi');

  const LivenessChallenge(this.instruction);
  final String instruction;
}

enum LivenessStatus { idle, running, passed, failed }

/// Tahap internal tiap tantangan.
enum _Phase { waitOpen, waitClosed, waitReopen, waitTurn, waitCenter, done }

/// Hasil satu kali pembaruan sesi, siap dipakai langsung oleh UI.
class LivenessUpdate {
  final LivenessStatus status;

  /// Teks yang ditampilkan ke pengguna saat ini.
  final String instruction;

  /// Tantangan yang sudah lulus dibagi total tantangan, 0 sampai 1.
  final double progress;

  const LivenessUpdate({
    required this.status,
    required this.instruction,
    required this.progress,
  });
}

/// Uji keaktifan wajah: pengguna harus berkedip dan menggerakkan kepala
/// sebelum presensi diterima.
///
/// Tujuannya menutup celah paling mudah, yaitu menyodorkan foto cetak atau foto
/// di layar ponsel lain ke kamera. Foto mati tidak bisa berkedip maupun
/// menoleh, jadi tidak akan pernah melewati sesi ini.
///
/// Seluruh kelas ini Dart murni: masuk [FaceSignals], keluar [LivenessUpdate].
/// Tidak ada kamera, ML Kit, maupun Firebase di dalamnya, sehingga perilakunya
/// bisa diuji sepenuhnya lewat `test/liveness_session_test.dart`.
class LivenessSession {
  LivenessSession(this.challenges);

  /// Urutan tantangan diacak supaya perekaman video satu sesi tidak bisa
  /// diputar ulang begitu saja pada sesi berikutnya.
  factory LivenessSession.random({Random? random}) {
    final shuffled = List<LivenessChallenge>.from(LivenessChallenge.values);
    shuffled.shuffle(random ?? Random());
    return LivenessSession(shuffled);
  }

  final List<LivenessChallenge> challenges;

  int _index = 0;
  _Phase _phase = _Phase.waitOpen;
  LivenessStatus _status = LivenessStatus.idle;
  DateTime? _challengeStartedAt;

  LivenessStatus get status => _status;
  int get passedCount => _index;

  LivenessChallenge? get currentChallenge =>
      _index < challenges.length ? challenges[_index] : null;

  double get progress =>
      challenges.isEmpty ? 1 : _index / challenges.length;

  /// Memulai, atau mengulang dari awal setelah gagal.
  LivenessUpdate start(DateTime now) {
    _index = 0;
    _status = LivenessStatus.running;
    _challengeStartedAt = now;
    _phase = _initialPhaseFor(challenges.first);
    return _buildUpdate(challenges.first.instruction);
  }

  _Phase _initialPhaseFor(LivenessChallenge challenge) {
    return switch (challenge) {
      LivenessChallenge.blink => _Phase.waitOpen,
      LivenessChallenge.turnHead => _Phase.waitTurn,
    };
  }

  /// Memproses satu frame.
  ///
  /// [now] diterima sebagai parameter, bukan dibaca dari `DateTime.now()` di
  /// dalam, supaya batas waktu bisa diuji tanpa benar-benar menunggu.
  LivenessUpdate update(FaceSignals signals, DateTime now) {
    if (_status != LivenessStatus.running) {
      return _buildUpdate(
        _status == LivenessStatus.passed
            ? 'Verifikasi berhasil'
            : 'Tekan tombol untuk memulai',
      );
    }

    final challenge = currentChallenge;
    if (challenge == null) {
      _status = LivenessStatus.passed;
      return _buildUpdate('Verifikasi berhasil');
    }

    final startedAt = _challengeStartedAt;
    if (startedAt != null && now.difference(startedAt) > kChallengeTimeout) {
      _status = LivenessStatus.failed;
      return _buildUpdate('Waktu habis. Coba lagi.');
    }

    if (!signals.hasFace) {
      return _buildUpdate('Wajah tidak terlihat. Tetap di dalam bingkai.');
    }

    final advanced = switch (challenge) {
      LivenessChallenge.blink => _handleBlink(signals),
      LivenessChallenge.turnHead => _handleTurnHead(signals),
    };

    if (!advanced) return _buildUpdate(_hintFor(challenge));

    _index++;
    final next = currentChallenge;
    if (next == null) {
      _status = LivenessStatus.passed;
      return _buildUpdate('Verifikasi berhasil');
    }

    _phase = _initialPhaseFor(next);
    _challengeStartedAt = now;
    return _buildUpdate(next.instruction);
  }

  /// Kedipan sah harus melewati tiga tahap: mata terbuka, lalu terpejam, lalu
  /// terbuka lagi. Memeriksa "mata terpejam" saja tidak cukup — foto orang
  /// dengan mata tertutup akan langsung lolos.
  bool _handleBlink(FaceSignals signals) {
    final eyeOpen = signals.eyeOpenProbability;
    if (eyeOpen == null) return false;

    switch (_phase) {
      case _Phase.waitOpen:
        if (eyeOpen >= kEyeOpenThreshold) _phase = _Phase.waitClosed;
        return false;
      case _Phase.waitClosed:
        if (eyeOpen <= kEyeClosedThreshold) _phase = _Phase.waitReopen;
        return false;
      case _Phase.waitReopen:
        if (eyeOpen >= kEyeOpenThreshold) {
          _phase = _Phase.done;
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  /// Gerakan kepala sah harus menoleh melewati ambang, lalu kembali ke tengah.
  /// Menuntut kembali ke tengah membuat tantangan ini sebuah gerakan, bukan
  /// sekadar satu pose miring yang bisa dipenuhi foto yang dimiringkan.
  ///
  /// Yang diperiksa hanya besar sudutnya, bukan arahnya. Tanda sudut dari ML
  /// Kit bergantung pada orientasi sensor kamera depan tiap perangkat, jadi
  /// menuntut arah tertentu akan menolak pengguna pada sebagian ponsel.
  bool _handleTurnHead(FaceSignals signals) {
    final angle = signals.headAngleY;
    if (angle == null) return false;

    switch (_phase) {
      case _Phase.waitTurn:
        if (angle.abs() >= kHeadTurnThreshold) _phase = _Phase.waitCenter;
        return false;
      case _Phase.waitCenter:
        if (angle.abs() <= kHeadCenterThreshold) {
          _phase = _Phase.done;
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  /// Petunjuk yang lebih spesifik sesuai tahap yang sedang ditunggu, supaya
  /// pengguna tahu apa yang kurang.
  String _hintFor(LivenessChallenge challenge) {
    return switch (_phase) {
      _Phase.waitOpen => 'Buka mata Anda, lalu berkedip',
      _Phase.waitClosed => 'Sekarang kedipkan mata',
      _Phase.waitReopen => 'Buka mata kembali',
      _Phase.waitTurn => 'Putar kepala ke samping',
      _Phase.waitCenter => 'Bagus, sekarang hadap depan lagi',
      _Phase.done => challenge.instruction,
    };
  }

  LivenessUpdate _buildUpdate(String instruction) => LivenessUpdate(
        status: _status,
        instruction: instruction,
        progress: progress,
      );
}
