import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../models/person.dart';
import '../providers/people_provider.dart';
import '../repositories/attendance_repo.dart';
import '../services/face_camera.dart';
import 'admin_screen.dart';
import 'leave_form_screen.dart';
import 'result_screen.dart';
import 'scan_screen.dart';

class KioskHomeScreen extends StatefulWidget {
  /// Overrides for tests.
  final FaceCamera Function()? cameraFactory;
  final Duration? pollInterval;

  const KioskHomeScreen({super.key, this.cameraFactory, this.pollInterval});

  @override
  State<KioskHomeScreen> createState() => _KioskHomeScreenState();
}

class _KioskHomeScreenState extends State<KioskHomeScreen> {
  final _time = DateFormat.Hm();
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<Person?> _scan(String title) => Navigator.of(context).push<Person>(
        MaterialPageRoute(
          builder: (_) => ScanScreen(
            title: title,
            people: context.read<PeopleProvider>().people,
            cameraFactory: widget.cameraFactory,
            pollInterval: widget.pollInterval,
          ),
        ),
      );

  Future<void> _show(String name, String message, {bool ok = true}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(name: name, message: message, ok: ok),
      ));

  Future<void> _absen() async {
    final person = await _scan('Absen');
    if (person == null || !mounted) return;
    final repo = context.read<AttendanceRepo>();
    try {
      final r = await repo.record(person.id);
      final (message, ok) = switch (r.outcome) {
        AttendanceOutcome.checkedIn => (
            'Absen masuk ${_time.format(r.attendance.checkIn)}',
            true
          ),
        AttendanceOutcome.checkedOut => (
            'Absen pulang ${_time.format(r.attendance.checkOut!)}',
            true
          ),
        AttendanceOutcome.alreadyCheckedIn => (
            'Sudah absen masuk ${_time.format(r.attendance.checkIn)}',
            false
          ),
        AttendanceOutcome.alreadyDone => (
            'Absensi hari ini sudah selesai',
            false
          ),
      };
      if (mounted) await _show(person.name, message, ok: ok);
    } on AppException catch (e) {
      if (mounted) await _show(person.name, e.message, ok: false);
    }
  }

  Future<void> _izin() async {
    final person = await _scan('Izin');
    if (person == null || !mounted) return;
    final filed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LeaveFormScreen(person: person)),
    );
    if (filed == true && mounted) {
      await _show(person.name, 'Izin tercatat');
    }
  }

  void _admin() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AdminScreen(
          cameraFactory: widget.cameraFactory,
          pollInterval: widget.pollInterval,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const big = Size(double.infinity, 96);
    const bigStyle = TextStyle(fontSize: 28, fontWeight: FontWeight.w600);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_time.format(_now),
                          textAlign: TextAlign.center,
                          style: text.displayLarge
                              ?.copyWith(fontWeight: FontWeight.w300)),
                      Text(DateFormat('EEEE, d MMMM y').format(_now),
                          textAlign: TextAlign.center, style: text.titleLarge),
                      const SizedBox(height: 40),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: big, textStyle: bigStyle),
                        icon: const Icon(Icons.face, size: 36),
                        onPressed: _absen,
                        label: const Text('Absen'),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: big, textStyle: bigStyle),
                        icon: const Icon(Icons.event_busy, size: 36),
                        onPressed: _izin,
                        label: const Text('Izin'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: IconButton(
                tooltip: 'Kelola',
                icon: const Icon(Icons.settings_outlined),
                onPressed: _admin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
