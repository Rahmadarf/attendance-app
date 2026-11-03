import '../core/errors.dart';
import '../core/store.dart';
import '../models/person.dart';
import 'attendance_repo.dart';
import 'leave_repo.dart';

class PersonRepo {
  static const table = 'people';

  final JsonStore store;
  PersonRepo(this.store);

  Future<List<Person>> list() async {
    final people = store.rows(table).map(Person.fromMap).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return people;
  }

  Future<Person> add(String name, List<List<double>> faces) async {
    final clean = name.trim();
    if (clean.isEmpty) throw const AppException('Nama wajib diisi.');
    if (faces.isEmpty) throw const AppException('Data wajah kosong.');
    final rows = store.rows(table);
    if (rows.any((r) => (r['name'] as String).toLowerCase() == clean.toLowerCase())) {
      throw const AppException('Nama sudah terdaftar.');
    }
    final row = <String, Object?>{
      'id': JsonStore.nextId(rows),
      'name': clean,
      'faces': faces,
    };
    await store.save(table, [...rows, row]);
    return Person.fromMap(row);
  }

  /// Removes the person and all of their attendance and leave records.
  Future<void> remove(int id) async {
    bool other(JsonRow r) => r['person_id'] != id;
    await store.save(AttendanceRepo.table,
        store.rows(AttendanceRepo.table).where(other).toList());
    await store.save(
        LeaveRepo.table, store.rows(LeaveRepo.table).where(other).toList());
    await store.save(
        table, store.rows(table).where((r) => r['id'] != id).toList());
  }
}
