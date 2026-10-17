import 'package:attendance_app/services/admin_repository.dart';
import 'package:attendance_app/services/admin_session.dart';
import 'package:attendance_app/utils/admin_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Penjaga layar admin: meminta PIN sebelum [child] boleh ditampilkan.
///
/// Dipakai membungkus layar Data Wajah Siswa, supaya pendaftaran dan
/// penghapusan wajah tidak terbuka bagi siapa pun yang memegang HP.
///
/// Saat pertama kali dipakai belum ada PIN sama sekali, jadi layar ini
/// menawarkan pembuatan PIN lebih dulu. Itu lebih baik daripada menanam PIN
/// bawaan di dalam kode, yang akan ikut terbaca siapa pun yang membuka
/// repositori ini.
class AdminGate extends StatefulWidget {
  final Widget child;

  /// Judul layar kunci, dipakai juga saat pembuatan PIN pertama.
  final String title;

  const AdminGate({
    super.key,
    required this.child,
    this.title = "Area Admin",
  });

  @override
  State<AdminGate> createState() => _AdminGateState();
}

enum _GateState { loading, needsSetup, locked, unlocked, error }

class _AdminGateState extends State<AdminGate> {
  final AdminRepository repository = AdminRepository();
  final AdminSession session = AdminSession.instance;

  final TextEditingController pinController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  _GateState state = _GateState.loading;
  AdminCredential? credential;
  String? errorMessage;
  String? loadError;
  bool isWorking = false;

  /// Percobaan PIN yang gagal berturut-turut.
  ///
  /// Setelah beberapa kali salah, tombolnya dijeda sebentar. PIN enam digit
  /// cukup pendek untuk ditebak satu per satu kalau boleh dicoba tanpa henti.
  int failedAttempts = 0;
  DateTime? lockedOutUntil;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    pinController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (session.isUnlocked(DateTime.now())) {
      setState(() => state = _GateState.unlocked);
      return;
    }

    setState(() => state = _GateState.loading);
    try {
      final stored = await repository.fetch();
      if (!mounted) return;
      setState(() {
        credential = stored;
        state = stored == null ? _GateState.needsSetup : _GateState.locked;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadError = "Gagal membaca pengaturan admin: $e";
        state = _GateState.error;
      });
    }
  }

  Duration? get _lockoutRemaining {
    final until = lockedOutUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  Future<void> _submitPin() async {
    final remaining = _lockoutRemaining;
    if (remaining != null) {
      setState(() {
        errorMessage =
            "Terlalu banyak percobaan. Tunggu ${remaining.inSeconds} detik.";
      });
      return;
    }

    final pin = pinController.text;
    final stored = credential;
    if (stored == null) return;

    setState(() => isWorking = true);
    // Hash diulang puluhan ribu kali, jadi beri kesempatan satu frame agar
    // indikator sibuknya sempat tergambar sebelum UI tertahan.
    await Future<void>.delayed(Duration.zero);

    final accepted = stored.matches(pin);
    if (!mounted) return;

    if (!accepted) {
      failedAttempts++;
      setState(() {
        isWorking = false;
        errorMessage = "PIN salah. Coba lagi.";
        if (failedAttempts >= 5) {
          lockedOutUntil = DateTime.now().add(const Duration(seconds: 30));
          failedAttempts = 0;
          errorMessage = "PIN salah 5 kali. Tunggu 30 detik sebelum mencoba lagi.";
        }
      });
      pinController.clear();
      return;
    }

    session.unlock(DateTime.now());
    pinController.clear();
    setState(() {
      isWorking = false;
      failedAttempts = 0;
      errorMessage = null;
      state = _GateState.unlocked;
    });
  }

  Future<void> _createPin() async {
    final pin = pinController.text;
    final confirm = confirmController.text;

    if (!isValidPinFormat(pin)) {
      setState(() => errorMessage = "PIN harus $kAdminPinLength digit angka.");
      return;
    }
    if (pin != confirm) {
      setState(() => errorMessage = "Konfirmasi PIN tidak sama.");
      return;
    }

    setState(() {
      isWorking = true;
      errorMessage = null;
    });

    try {
      await repository.setPin(pin);
      if (!mounted) return;
      session.unlock(DateTime.now());
      pinController.clear();
      confirmController.clear();
      setState(() {
        isWorking = false;
        state = _GateState.unlocked;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isWorking = false;
        errorMessage = "Gagal menyimpan PIN: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sesi bisa kedaluwarsa selagi layar ini terbuka, misalnya HP ditinggal.
    if (state == _GateState.unlocked && !session.isUnlocked(DateTime.now())) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    return switch (state) {
      _GateState.unlocked => widget.child,
      _GateState.loading => _scaffold(
          const Center(child: CircularProgressIndicator()),
        ),
      _GateState.error => _scaffold(_buildError()),
      _GateState.needsSetup => _scaffold(_buildSetupForm()),
      _GateState.locked => _scaffold(_buildUnlockForm()),
    };
  }

  Widget _scaffold(Widget body) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(child: body),
      );

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              loadError ?? "Terjadi kesalahan.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockForm() {
    return _formShell(
      icon: Icons.lock_outline,
      title: "Masukkan PIN Admin",
      subtitle: "Hanya guru atau petugas yang boleh membuka data wajah siswa.",
      children: [
        _buildPinField(
          controller: pinController,
          label: "PIN Admin",
          onSubmitted: (_) => _submitPin(),
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: "Buka",
          icon: Icons.lock_open_outlined,
          onPressed: _submitPin,
        ),
      ],
    );
  }

  Widget _buildSetupForm() {
    return _formShell(
      icon: Icons.key_outlined,
      title: "Buat PIN Admin",
      subtitle:
          "Belum ada PIN yang tersimpan. Buat sekarang untuk mengunci menu "
          "Data Wajah Siswa. PIN disimpan dalam bentuk hash, bukan apa adanya.",
      children: [
        _buildPinField(
          controller: pinController,
          label: "PIN Baru",
        ),
        const SizedBox(height: 16),
        _buildPinField(
          controller: confirmController,
          label: "Ulangi PIN",
          onSubmitted: (_) => _createPin(),
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: "Simpan PIN",
          icon: Icons.save_outlined,
          onPressed: _createPin,
        ),
      ],
    );
  }

  Widget _formShell({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 56, color: const Color(0xFF1A008F)),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A008F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              ...children,
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      enabled: !isWorking,
      keyboardType: TextInputType.number,
      maxLength: kAdminPinLength,
      textAlign: TextAlign.center,
      onSubmitted: onSubmitted,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 22, letterSpacing: 10),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        counterText: "",
        prefixIcon: const Icon(Icons.pin_outlined),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: isWorking ? null : onPressed,
      icon: isWorking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(isWorking ? "Memproses..." : label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A008F),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
