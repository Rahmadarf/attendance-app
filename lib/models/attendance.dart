class Attendance {
  final int id;
  final int personId;
  final String date; // yyyy-MM-dd
  final DateTime checkIn;
  final DateTime? checkOut;

  const Attendance({
    required this.id,
    required this.personId,
    required this.date,
    required this.checkIn,
    this.checkOut,
  });

  factory Attendance.fromMap(Map<String, Object?> m) => Attendance(
        id: m['id'] as int,
        personId: m['person_id'] as int,
        date: m['date'] as String,
        checkIn: DateTime.parse(m['check_in'] as String),
        checkOut: m['check_out'] == null
            ? null
            : DateTime.parse(m['check_out'] as String),
      );
}
