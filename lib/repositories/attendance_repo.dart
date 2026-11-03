import '../core/dates.dart';
import '../core/errors.dart';
import '../core/store.dart';
import '../models/attendance.dart';
import 'leave_repo.dart';

enum AttendanceOutcome {
  checkedIn,
  checkedOut,

  /// Scanned again right after checking in; nothing changed.
  alreadyCheckedIn,

  /// Already checked in and out today; nothing changed.
  alreadyDone,
}

class AttendanceResult {
  final AttendanceOutcome outcome;
  final Attendance attendance;
  const AttendanceResult(this.outcome, this.attendance);
}

class AttendanceRepo {
  static const table = 'attendance';

  /// A second scan sooner than this after check-in is not treated as check-out.
  static const minStay = Duration(minutes: 5);

  final JsonStore store;
  final LeaveRepo leaves;
  AttendanceRepo(this.store, this.leaves);

  JsonRow? _find(List<JsonRow> rows, int personId, String date) => rows
      .where((r) => r['person_id'] == personId && r['date'] == date)
      .firstOrNull;

  Future<Attendance?> today(int personId, [DateTime? now]) async {
    final row =
        _find(store.rows(table), personId, dateKey(now ?? DateTime.now()));
    return row == null ? null : Attendance.fromMap(row);
  }

  /// One-button flow: check in, then check out, then "done" for the day.
  Future<AttendanceResult> record(int personId, [DateTime? now]) async {
    final t = now ?? DateTime.now();
    final current = await today(personId, t);
    if (current == null) {
      return AttendanceResult(
          AttendanceOutcome.checkedIn, await checkIn(personId, t));
    }
    if (current.checkOut != null) {
      return AttendanceResult(AttendanceOutcome.alreadyDone, current);
    }
    if (t.difference(current.checkIn) < minStay) {
      return AttendanceResult(AttendanceOutcome.alreadyCheckedIn, current);
    }
    return AttendanceResult(
        AttendanceOutcome.checkedOut, await checkOut(personId, t));
  }

  Future<Attendance> checkIn(int personId, [DateTime? now]) async {
    final t = now ?? DateTime.now();
    if (await leaves.onLeave(personId, t)) {
      throw const AppException('Hari ini kamu sedang izin, tidak bisa absen.');
    }
    final rows = store.rows(table);
    if (_find(rows, personId, dateKey(t)) != null) {
      throw const AppException('Kamu sudah absen masuk hari ini.');
    }
    final row = <String, Object?>{
      'id': JsonStore.nextId(rows),
      'person_id': personId,
      'date': dateKey(t),
      'check_in': t.toIso8601String(),
      'check_out': null,
    };
    await store.save(table, [...rows, row]);
    return Attendance.fromMap(row);
  }

  Future<Attendance> checkOut(int personId, [DateTime? now]) async {
    final t = now ?? DateTime.now();
    final rows = store.rows(table);
    final row = _find(rows, personId, dateKey(t));
    if (row == null) {
      throw const AppException('Belum absen masuk hari ini.');
    }
    if (row['check_out'] != null) {
      throw const AppException('Kamu sudah absen pulang hari ini.');
    }
    row['check_out'] = t.toIso8601String();
    await store.save(table, rows);
    return Attendance.fromMap(row);
  }

  /// Everyone's records for [day], earliest check-in first.
  Future<List<Attendance>> forDate(DateTime day) async {
    final k = dateKey(day);
    final rows = store.rows(table).where((r) => r['date'] == k).toList()
      ..sort((a, b) =>
          (a['check_in'] as String).compareTo(b['check_in'] as String));
    return rows.map(Attendance.fromMap).toList();
  }
}
