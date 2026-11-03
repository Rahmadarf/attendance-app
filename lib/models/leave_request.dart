enum LeaveType {
  sakit('Sakit'),
  izin('Izin'),
  lainnya('Lainnya');

  final String label;
  const LeaveType(this.label);

  static LeaveType parse(String v) =>
      LeaveType.values.firstWhere((e) => e.name == v, orElse: () => lainnya);
}

class LeaveRequest {
  final int id;
  final int personId;
  final LeaveType type;
  final String startDate; // yyyy-MM-dd
  final String endDate; // yyyy-MM-dd
  final String reason;
  final DateTime createdAt;

  const LeaveRequest({
    required this.id,
    required this.personId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.createdAt,
  });

  factory LeaveRequest.fromMap(Map<String, Object?> m) => LeaveRequest(
        id: m['id'] as int,
        personId: m['person_id'] as int,
        type: LeaveType.parse(m['type'] as String),
        startDate: m['start_date'] as String,
        endDate: m['end_date'] as String,
        reason: m['reason'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
