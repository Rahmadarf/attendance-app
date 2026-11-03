import '../core/dates.dart';
import '../core/errors.dart';
import '../core/store.dart';
import '../models/leave_request.dart';

class LeaveRepo {
  static const table = 'leave_requests';

  final JsonStore store;
  LeaveRepo(this.store);

  /// [reason] is optional so a leave can be filed with a couple of taps.
  Future<LeaveRequest> submit({
    required int personId,
    required LeaveType type,
    required DateTime start,
    required DateTime end,
    String reason = '',
    DateTime? now,
  }) async {
    final s = dateKey(start);
    final e = dateKey(end);
    if (e.compareTo(s) < 0) {
      throw const AppException('Tanggal akhir tidak boleh sebelum tanggal mulai.');
    }
    final rows = store.rows(table);
    // Overlap: existing.start <= new.end AND existing.end >= new.start.
    final overlap = rows.any((r) =>
        r['person_id'] == personId &&
        (r['start_date'] as String).compareTo(e) <= 0 &&
        (r['end_date'] as String).compareTo(s) >= 0);
    if (overlap) {
      throw const AppException('Tanggal bertabrakan dengan izin yang sudah ada.');
    }
    final row = <String, Object?>{
      'id': JsonStore.nextId(rows),
      'person_id': personId,
      'type': type.name,
      'start_date': s,
      'end_date': e,
      'reason': reason.trim(),
      'created_at': (now ?? DateTime.now()).toIso8601String(),
    };
    await store.save(table, [...rows, row]);
    return LeaveRequest.fromMap(row);
  }

  /// Every leave, newest first (for the admin view).
  Future<List<LeaveRequest>> all() async {
    final rows = store.rows(table)
      ..sort((a, b) =>
          (b['start_date'] as String).compareTo(a['start_date'] as String));
    return rows.map(LeaveRequest.fromMap).toList();
  }

  Future<bool> onLeave(int personId, DateTime day) async {
    final k = dateKey(day);
    return store.rows(table).any((r) =>
        r['person_id'] == personId &&
        (r['start_date'] as String).compareTo(k) <= 0 &&
        (r['end_date'] as String).compareTo(k) >= 0);
  }
}
