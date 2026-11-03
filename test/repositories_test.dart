import 'package:attendance_app/core/errors.dart';
import 'package:attendance_app/core/store.dart';
import 'package:attendance_app/models/leave_request.dart';
import 'package:attendance_app/repositories/attendance_repo.dart';
import 'package:attendance_app/repositories/leave_repo.dart';
import 'package:attendance_app/repositories/person_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void main() {
  late PersonRepo people;
  late LeaveRepo leaves;
  late AttendanceRepo attendance;
  late int pid;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = JsonStore(await SharedPreferences.getInstance());
    people = PersonRepo(store);
    leaves = LeaveRepo(store);
    attendance = AttendanceRepo(store, leaves);
    pid = (await people.add('Budi', [embed(0)])).id;
  });

  group('PersonRepo', () {
    test('add stores embeddings and lists sorted by name', () async {
      await people.add('Ana', [embed(1), embed(1, jitter: 0.1)]);
      final list = await people.list();
      expect(list.map((p) => p.name), ['Ana', 'Budi']);
      expect(list.first.faces.length, 2);
      expect(list.first.faces.first, embed(1));
    });

    test('rejects blank name, no faces, duplicate name', () async {
      expect(people.add('  ', [embed(1)]), throwsA(isA<AppException>()));
      expect(people.add('Cici', []), throwsA(isA<AppException>()));
      expect(people.add('budi', [embed(1)]), throwsA(isA<AppException>()));
    });

    test('remove also deletes that person\'s records', () async {
      final other = (await people.add('Ana', [embed(1)])).id;
      final day = DateTime(2026, 11, 3, 8);
      await attendance.checkIn(pid, day);
      await attendance.checkIn(other, day);
      await leaves.submit(
          personId: pid,
          type: LeaveType.sakit,
          start: DateTime(2026, 11, 10),
          end: DateTime(2026, 11, 10));

      await people.remove(pid);

      expect((await people.list()).map((p) => p.id), [other]);
      expect((await attendance.forDate(day)).map((a) => a.personId), [other]);
      expect(await leaves.all(), isEmpty);
    });
  });

  group('AttendanceRepo.record', () {
    final t0 = DateTime(2026, 11, 3, 8, 0);

    test('masuk, then pulang, then selesai', () async {
      final a = await attendance.record(pid, t0);
      expect(a.outcome, AttendanceOutcome.checkedIn);

      final b = await attendance.record(pid, t0.add(const Duration(hours: 8)));
      expect(b.outcome, AttendanceOutcome.checkedOut);
      expect(b.attendance.checkOut, isNotNull);

      final c = await attendance.record(pid, t0.add(const Duration(hours: 9)));
      expect(c.outcome, AttendanceOutcome.alreadyDone);
      expect((await attendance.forDate(t0)).length, 1);
    });

    test('second scan within 5 minutes is not a check-out', () async {
      await attendance.record(pid, t0);
      final r = await attendance.record(pid, t0.add(const Duration(minutes: 2)));
      expect(r.outcome, AttendanceOutcome.alreadyCheckedIn);
      expect(r.attendance.checkOut, isNull);
      final later =
          await attendance.record(pid, t0.add(const Duration(minutes: 5)));
      expect(later.outcome, AttendanceOutcome.checkedOut);
    });

    test('blocked on a leave day, fine the next day', () async {
      await leaves.submit(
          personId: pid,
          type: LeaveType.sakit,
          start: DateTime(2026, 11, 3),
          end: DateTime(2026, 11, 4),
          reason: 'Demam');
      expect(attendance.record(pid, t0), throwsA(isA<AppException>()));
      final r = await attendance.record(pid, DateTime(2026, 11, 5, 8));
      expect(r.outcome, AttendanceOutcome.checkedIn);
    });

    test('each person has their own record', () async {
      final other = (await people.add('Ana', [embed(1)])).id;
      await attendance.record(pid, t0);
      final r = await attendance.record(other, t0);
      expect(r.outcome, AttendanceOutcome.checkedIn);
      expect((await attendance.forDate(t0)).length, 2);
    });
  });

  group('LeaveRepo', () {
    test('reason is optional', () async {
      final l = await leaves.submit(
          personId: pid,
          type: LeaveType.izin,
          start: DateTime(2026, 11, 5),
          end: DateTime(2026, 11, 5));
      expect(l.reason, '');
    });

    test('end before start rejected', () {
      expect(
        leaves.submit(
            personId: pid,
            type: LeaveType.izin,
            start: DateTime(2026, 11, 5),
            end: DateTime(2026, 11, 4)),
        throwsA(isA<AppException>()),
      );
    });

    test('overlap rejected for same person, adjacent and others allowed',
        () async {
      final other = (await people.add('Ana', [embed(1)])).id;
      await leaves.submit(
          personId: pid,
          type: LeaveType.izin,
          start: DateTime(2026, 11, 10),
          end: DateTime(2026, 11, 12));
      expect(
        leaves.submit(
            personId: pid,
            type: LeaveType.izin,
            start: DateTime(2026, 11, 12),
            end: DateTime(2026, 11, 14)),
        throwsA(isA<AppException>()),
      );
      await leaves.submit(
          personId: pid,
          type: LeaveType.izin,
          start: DateTime(2026, 11, 13),
          end: DateTime(2026, 11, 14));
      await leaves.submit(
          personId: other,
          type: LeaveType.izin,
          start: DateTime(2026, 11, 10),
          end: DateTime(2026, 11, 12));
      expect((await leaves.all()).length, 3);
    });
  });
}
