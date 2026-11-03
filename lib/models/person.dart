/// A registered person. [faces] holds face embeddings (numbers, not photos),
/// one per enrolment sample.
class Person {
  final int id;
  final String name;
  final List<List<double>> faces;

  const Person({required this.id, required this.name, required this.faces});

  factory Person.fromMap(Map<String, Object?> m) => Person(
        id: m['id'] as int,
        name: m['name'] as String,
        faces: (m['faces'] as List)
            .map((f) =>
                (f as List).map((n) => (n as num).toDouble()).toList())
            .toList(),
      );
}
