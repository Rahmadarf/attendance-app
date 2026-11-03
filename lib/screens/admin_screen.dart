import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/errors.dart';
import '../models/attendance.dart';
import '../models/leave_request.dart';
import '../providers/people_provider.dart';
import '../repositories/attendance_repo.dart';
import '../repositories/leave_repo.dart';
import '../services/admin_pin.dart';
import '../services/face_camera.dart';
import 'enroll_screen.dart';

/// PIN-protected management area: people, attendance log, leave log.
class AdminScreen extends StatefulWidget {
  /// Overrides for tests.
  final FaceCamera Function()? cameraFactory;
  final Duration? pollInterval;

  const AdminScreen({super.key, this.cameraFactory, this.pollInterval});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    context.read<PeopleProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return _PinGate(onUnlocked: () => setState(() => _unlocked = true));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola'),
          actions: [
            IconButton(
              tooltip: 'Ganti PIN',
              icon: const Icon(Icons.password),
              onPressed: () => _changePin(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Orang'), Tab(text: 'Absensi'), Tab(text: 'Izin')],
          ),
        ),
        body: TabBarView(children: [
          _PeopleTab(
              cameraFactory: widget.cameraFactory,
              pollInterval: widget.pollInterval),
          const _AttendanceTab(),
          const _LeaveTab(),
        ]),
      ),
    );
  }

  Future<void> _changePin(BuildContext context) async {
    final pin = context.read<AdminPin>();
    final messenger = ScaffoldMessenger.of(context);
    final ctl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN baru'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minimal 4 angka'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('Simpan')),
        ],
      ),
    );
    ctl.dispose();
    if (value == null) return;
    try {
      await pin.set(value);
      messenger.showSnackBar(const SnackBar(content: Text('PIN diganti')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _PinGate extends StatefulWidget {
  final VoidCallback onUnlocked;
  const _PinGate({required this.onUnlocked});

  @override
  State<_PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<_PinGate> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = context.read<AdminPin>();
    final creating = !store.isSet;
    try {
      if (creating) {
        if (_pin.text != _confirm.text) {
          return setState(() => _error = 'PIN tidak sama.');
        }
        await store.set(_pin.text);
        widget.onUnlocked();
      } else if (await store.verify(_pin.text)) {
        widget.onUnlocked();
      } else {
        _pin.clear();
        if (mounted) setState(() => _error = 'PIN salah.');
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = !context.read<AdminPin>().isSet;
    return Scaffold(
      appBar: AppBar(title: Text(creating ? 'Buat PIN admin' : 'PIN admin')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (creating)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                        'Belum ada PIN. Buat PIN (minimal 4 angka) untuk melindungi menu Kelola.'),
                  ),
                TextField(
                  controller: _pin,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: creating ? 'PIN baru' : 'PIN',
                      errorText: _error),
                  onSubmitted: (_) => creating ? null : _submit(),
                ),
                if (creating) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ulangi PIN'),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submit,
                  child: Text(creating ? 'Simpan PIN' : 'Buka'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeopleTab extends StatelessWidget {
  final FaceCamera Function()? cameraFactory;
  final Duration? pollInterval;
  const _PeopleTab({this.cameraFactory, this.pollInterval});

  Future<void> _delete(BuildContext context, int id, String name) async {
    final provider = context.read<PeopleProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $name?'),
        content: const Text(
            'Data wajah, absensi, dan izin orang ini ikut terhapus. Tidak bisa dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) await provider.remove(id);
  }

  @override
  Widget build(BuildContext context) {
    final people = context.watch<PeopleProvider>().people;
    return Scaffold(
      body: people.isEmpty
          ? const Center(child: Text('Belum ada orang terdaftar'))
          : ListView.separated(
              itemCount: people.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = people[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.faces.length} sampel wajah'),
                  trailing: IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, p.id, p.name),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah orang'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EnrollScreen(
              cameraFactory: cameraFactory, pollInterval: pollInterval),
        )),
      ),
    );
  }
}

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  DateTime _day = DateTime.now();
  late Future<List<Attendance>> _future = _load();

  Future<List<Attendance>> _load() =>
      context.read<AttendanceRepo>().forDate(_day);

  void _go(DateTime d) => setState(() {
        _day = d;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final people = context.watch<PeopleProvider>();
    final time = DateFormat.Hm();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Hari sebelumnya',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _go(_day.subtract(const Duration(days: 1))),
            ),
            TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) _go(d);
              },
              child: Text(DateFormat('EEEE, d MMM y').format(_day)),
            ),
            IconButton(
              tooltip: 'Hari berikutnya',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _go(_day.add(const Duration(days: 1))),
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<Attendance>>(
            future: _future,
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return const Center(child: Text('Belum ada absensi'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final a = items[i];
                  return ListTile(
                    title: Text(people.byId(a.personId)?.name ?? '(dihapus)'),
                    subtitle: Text(
                        'Masuk ${time.format(a.checkIn)} · Pulang ${a.checkOut == null ? '-' : time.format(a.checkOut!)}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LeaveTab extends StatefulWidget {
  const _LeaveTab();

  @override
  State<_LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<_LeaveTab> {
  late final Future<List<LeaveRequest>> _future =
      context.read<LeaveRepo>().all();

  @override
  Widget build(BuildContext context) {
    final people = context.watch<PeopleProvider>();
    final day = DateFormat('d MMM y');
    return FutureBuilder<List<LeaveRequest>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data;
        if (items == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) return const Center(child: Text('Belum ada izin'));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final l = items[i];
            final range = l.startDate == l.endDate
                ? day.format(parseDateKey(l.startDate))
                : '${day.format(parseDateKey(l.startDate))} – ${day.format(parseDateKey(l.endDate))}';
            return ListTile(
              title: Text(
                  '${people.byId(l.personId)?.name ?? '(dihapus)'} · ${l.type.label}'),
              subtitle: Text(l.reason.isEmpty ? range : '$range\n${l.reason}'),
              isThreeLine: l.reason.isNotEmpty,
            );
          },
        );
      },
    );
  }
}
