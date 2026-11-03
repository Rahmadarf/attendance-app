import 'package:attendance_app/core/store.dart';
import 'package:attendance_app/main.dart';
import 'package:attendance_app/models/leave_request.dart';
import 'package:attendance_app/repositories/attendance_repo.dart';
import 'package:attendance_app/repositories/leave_repo.dart';
import 'package:attendance_app/repositories/person_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester t, [int ms = 500]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late SharedPreferences prefs;
  late JsonStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = JsonStore(prefs);
    await PersonRepo(store).add('Ana', [embed(0)]);
  });

  Future<void> open(WidgetTester t, FakeCamera cam) async {
    await t.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(AttendanceApp(
      prefs: prefs,
      cameraFactory: () => cam,
      pollInterval: const Duration(milliseconds: 100),
    ));
    await settle(t, 200);
  }

  Future<void> openAdmin(WidgetTester t) async {
    await t.tap(find.byTooltip('Kelola'));
    await settle(t);
  }

  Future<void> enterPin(WidgetTester t, String pin, {String? confirm}) async {
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), pin);
    if (confirm != null) await t.enterText(fields.at(1), confirm);
  }

  testWidgets('first use creates a PIN, later uses require it', (t) async {
    await open(t, FakeCamera([face(embed(0))]));

    await openAdmin(t);
    expect(find.text('Buat PIN admin'), findsOneWidget);
    await enterPin(t, '1234', confirm: '9999');
    await t.tap(find.text('Simpan PIN'));
    await settle(t);
    expect(find.text('PIN tidak sama.'), findsOneWidget);

    await enterPin(t, '1234', confirm: '1234');
    await t.tap(find.text('Simpan PIN'));
    await settle(t);
    expect(find.text('Kelola'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);

    // Leave and come back: PIN is now required.
    await t.pageBack();
    await settle(t);
    await openAdmin(t);
    expect(find.text('PIN admin'), findsOneWidget);
    await enterPin(t, '0000');
    await t.tap(find.text('Buka'));
    await settle(t);
    expect(find.text('PIN salah.'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);

    await enterPin(t, '1234');
    await t.tap(find.text('Buka'));
    await settle(t);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('add a person by scanning, then delete them', (t) async {
    // Three distinct samples of a new face (different axis from Ana).
    final cici = [
      face(embed(5)),
      face(embed(5, jitter: 0.01)),
      face(embed(5, jitter: 0.02)),
    ];
    await open(t, FakeCamera(cici));

    await openAdmin(t);
    await enterPin(t, '1234', confirm: '1234');
    await t.tap(find.text('Simpan PIN'));
    await settle(t);

    await t.tap(find.text('Tambah orang'));
    await settle(t);
    await t.enterText(find.byType(TextField), 'Cici');
    await t.tap(find.text('Mulai scan wajah'));
    await settle(t, 2000);

    // Back on the list with the new person and 3 samples.
    expect(find.text('Cici'), findsOneWidget);
    expect(find.text('3 sampel wajah'), findsOneWidget);
    final saved = (await PersonRepo(store).list()).firstWhere((p) => p.name == 'Cici');
    expect(saved.faces.length, 3);

    await t.tap(find.byTooltip('Hapus').last);
    await settle(t);
    expect(find.text('Hapus Cici?'), findsOneWidget);
    await t.tap(find.text('Hapus'));
    await settle(t);
    expect(find.text('Cici'), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('enrolling a face that is already registered is refused',
      (t) async {
    await open(t, FakeCamera([face(embed(0)), face(embed(0)), face(embed(0))]));
    await openAdmin(t);
    await enterPin(t, '1234', confirm: '1234');
    await t.tap(find.text('Simpan PIN'));
    await settle(t);

    await t.tap(find.text('Tambah orang'));
    await settle(t);
    await t.enterText(find.byType(TextField), 'Kembaran');
    await t.tap(find.text('Mulai scan wajah'));
    await settle(t, 2000);

    expect(find.text('Wajah ini sudah terdaftar sebagai Ana.'), findsOneWidget);
    expect((await PersonRepo(store).list()).map((p) => p.name), ['Ana']);
  });

  testWidgets('name checks happen before the camera opens', (t) async {
    await open(t, FakeCamera([face(embed(5))]));
    await openAdmin(t);
    await enterPin(t, '1234', confirm: '1234');
    await t.tap(find.text('Simpan PIN'));
    await settle(t);
    await t.tap(find.text('Tambah orang'));
    await settle(t);

    await t.tap(find.text('Mulai scan wajah'));
    await settle(t);
    expect(find.text('Nama wajib diisi.'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'ana');
    await t.tap(find.text('Mulai scan wajah'));
    await settle(t);
    expect(find.text('Nama sudah terdaftar.'), findsOneWidget);
    expect(find.text('Mulai scan wajah'), findsOneWidget); // still on the form
  });

  testWidgets('attendance and leave tabs list everyone\'s records', (t) async {
    final leaves = LeaveRepo(store);
    final attendance = AttendanceRepo(store, leaves);
    final ana = (await PersonRepo(store).list()).single;
    final now = DateTime.now();
    await attendance.checkIn(ana.id, DateTime(now.year, now.month, now.day, 8, 5));
    await leaves.submit(
        personId: ana.id,
        type: LeaveType.sakit,
        start: now.add(const Duration(days: 3)),
        end: now.add(const Duration(days: 3)),
        reason: 'Demam');

    await open(t, FakeCamera([face(embed(0))]));
    await openAdmin(t);
    await enterPin(t, '1234', confirm: '1234');
    await t.tap(find.text('Simpan PIN'));
    await settle(t);

    await t.tap(find.text('Absensi'));
    await settle(t);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.textContaining('Masuk 08:05'), findsOneWidget);

    await t.tap(find.text('Izin'));
    await settle(t);
    expect(find.textContaining('Ana · Sakit'), findsOneWidget);
    expect(find.textContaining('Demam'), findsOneWidget);
  });
}
