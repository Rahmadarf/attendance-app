import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../models/leave_request.dart';
import '../models/person.dart';
import '../repositories/leave_repo.dart';

/// Quick leave form for the scanned [person]. Pops `true` when filed.
class LeaveFormScreen extends StatefulWidget {
  final Person person;

  /// Back to the idle screen if nobody touches the form (public kiosk).
  final Duration idleTimeout;

  const LeaveFormScreen({
    super.key,
    required this.person,
    this.idleTimeout = const Duration(seconds: 60),
  });

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final _reason = TextEditingController();
  final _fmt = DateFormat('d MMM y');
  LeaveType _type = LeaveType.izin;
  DateTime _start = _today();
  DateTime _end = _today();
  bool _saving = false;
  Timer? _idle;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _touch();
  }

  void _touch() {
    _idle?.cancel();
    _idle = Timer(widget.idleTimeout, () {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final today = _today();
    _idle?.cancel(); // the date dialog is user activity
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: start ? today : _start,
      lastDate: today.add(const Duration(days: 365)),
    );
    _touch();
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    final repo = context.read<LeaveRepo>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await repo.submit(
        personId: widget.person.id,
        type: _type,
        start: _start,
        end: _end,
        reason: _reason.text,
      );
      navigator.pop(true);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touch(),
      child: Scaffold(
        appBar: AppBar(title: Text('Izin — ${widget.person.name}')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<LeaveType>(
                  segments: [
                    for (final t in LeaveType.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal mulai'),
                  subtitle: Text(_fmt.format(_start)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pick(start: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal akhir'),
                  subtitle: Text(_fmt.format(_end)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pick(start: false),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Alasan (boleh dikosongkan)',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  onPressed: _saving ? null : _submit,
                  child: const Text('Kirim Izin'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
