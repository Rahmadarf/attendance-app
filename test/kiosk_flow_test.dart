import 'package:attendance_app/core/store.dart';
import 'package:attendance_app/main.dart';
import 'package:attendance_app/repositories/leave_repo.dart';
import 'package:attendance_app/repositories/person_repo.dart';
import 'package:attendance_app/services/face_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

const _poll = Duration(milliseconds: 100);

/// Pump in small steps so timers, polls and route animations all advance.
Future<void> settle(WidgetTester t, [int ms = 1000]) async {
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
    final people = PersonRepo(store);
    await people.add('Ana', [embed(0)]);
    await people.add('Budi', [embed(3)]);
  });

  Future<FakeCamera> open(WidgetTester t, FakeCamera cam) async {
    await t.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(AttendanceApp(
      prefs: prefs,
      cameraFactory: () => cam,
      pollInterval: _poll,
    ));
    await settle(t, 200);
    return cam;
  }

  testWidgets('Absen: recognised face is recorded, result auto-closes',
      (t) async {
    await open(t, FakeCamera([face(embed(0, jitter: 0.02))]));

    await t.tap(find.text('Absen'));
    await settle(t, 1000);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.textContaining('Absen masuk'), findsOneWidget);

    await settle(t, 4500); // result closes itself
    expect(find.text('Ana'), findsNothing);
    expect(find.text('Absen'), findsOneWidget);

    // Scanning again straight away must not count as check-out.
    await t.tap(find.text('Absen'));
    await settle(t, 1000);
    expect(find.textContaining('Sudah absen masuk'), findsOneWidget);
    await settle(t, 4500);
  });

  testWidgets('unregistered face is not recorded', (t) async {
    await open(t, FakeCamera([face(embed(6))]));
    await t.tap(find.text('Absen'));
    await settle(t, 1500);
    expect(find.text('Wajah belum terdaftar. Hubungi admin.'), findsOneWidget);
    expect(find.text('Absen masuk'), findsNothing);
  });

  testWidgets('photo/screen (low anti-spoof score) is refused', (t) async {
    await open(t, FakeCamera([face(embed(0), real: 0.1)]));
    await t.tap(find.text('Absen'));
    await settle(t, 1500);
    expect(find.text('Gunakan wajah langsung, bukan foto atau layar'),
        findsOneWidget);
    expect(find.textContaining('Absen masuk'), findsNothing);
  });

  testWidgets('two faces in view are refused', (t) async {
    await open(t, FakeCamera([const FaceReading(faceCount: 2)]));
    await t.tap(find.text('Absen'));
    await settle(t, 1500);
    expect(find.text('Hanya satu wajah yang boleh terlihat'), findsOneWidget);
  });

  testWidgets('a flicker between people never reaches 3 in a row', (t) async {
    final ana = face(embed(0));
    final budi = face(embed(3));
    await open(t, FakeCamera([ana, ana, budi, ana, ana, budi, budi, budi]));
    await t.tap(find.text('Absen'));
    await settle(t, 1200);
    // 3 consecutive Budi frames at the end -> Budi, not Ana.
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
    await settle(t, 4500);
  });

  testWidgets('camera error is shown, nothing recorded', (t) async {
    await open(
        t,
        FakeCamera([face(embed(0))],
            failure: const FaceCameraException('Izin kamera ditolak.')));
    await t.tap(find.text('Absen'));
    await settle(t, 500);
    expect(find.text('Izin kamera ditolak.'), findsOneWidget);
  });

  testWidgets('no one registered -> asks to contact admin', (t) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await open(t, FakeCamera([face(embed(0))]));
    await t.tap(find.text('Absen'));
    await settle(t, 500);
    expect(find.text('Belum ada orang terdaftar. Hubungi admin.'),
        findsOneWidget);
  });

  testWidgets('Izin: scan, pick, send -> leave saved', (t) async {
    await open(t, FakeCamera([face(embed(0))]));
    await t.tap(find.text('Izin'));
    await settle(t, 1000);
    expect(find.text('Izin — Ana'), findsOneWidget);

    await t.tap(find.text('Sakit'));
    await t.pump();
    await t.tap(find.text('Kirim Izin'));
    await settle(t, 500);
    expect(find.text('Izin tercatat'), findsOneWidget);

    final saved = await LeaveRepo(store).all();
    expect(saved.length, 1);
    expect(saved.single.type.name, 'sakit');
    expect(saved.single.reason, '');
    await settle(t, 4500);
  });

  testWidgets('leave form returns to idle screen when left alone', (t) async {
    await open(t, FakeCamera([face(embed(0))]));
    await t.tap(find.text('Izin'));
    await settle(t, 1000);
    expect(find.text('Izin — Ana'), findsOneWidget);
    await settle(t, 61000);
    expect(find.text('Izin — Ana'), findsNothing);
    expect(find.text('Absen'), findsOneWidget);
  });
}
