import 'package:flutter/foundation.dart';

import '../models/person.dart';
import '../repositories/person_repo.dart';

class PeopleProvider extends ChangeNotifier {
  final PersonRepo _repo;
  PeopleProvider(this._repo);

  List<Person> _people = const [];
  List<Person> get people => _people;

  Person? byId(int id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> refresh() async {
    _people = await _repo.list();
    notifyListeners();
  }

  Future<void> add(String name, List<List<double>> faces) async {
    await _repo.add(name, faces);
    await refresh();
  }

  Future<void> remove(int id) async {
    await _repo.remove(id);
    await refresh();
  }
}
