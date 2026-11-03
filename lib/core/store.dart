import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

typedef JsonRow = Map<String, Object?>;

/// Tiny table store on top of [SharedPreferences] (localStorage on web).
///
/// Each table is a JSON list of rows. Reads are synchronous (SharedPreferences
/// keeps a cache), so a read-modify-write that only awaits the final [save]
/// cannot interleave with another call.
class JsonStore {
  final SharedPreferences _prefs;
  JsonStore(this._prefs);

  static String _key(String table) => 'table_v2_$table';

  List<JsonRow> rows(String table) {
    final raw = _prefs.getString(_key(table));
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList();
  }

  Future<void> save(String table, List<JsonRow> rows) async {
    final ok = await _prefs.setString(_key(table), jsonEncode(rows));
    if (!ok) throw StateError('Gagal menyimpan data ($table).');
  }

  /// Next auto-increment id for [rows].
  static int nextId(List<JsonRow> rows) =>
      rows.fold<int>(0, (m, r) => (r['id'] as int) > m ? r['id'] as int : m) + 1;
}
