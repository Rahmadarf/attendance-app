import 'package:attendance_app/utils/attendance_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAttendanceStatus', () {
    test('sebelum pukul 08:30 terhitung Attend', () {
      expect(resolveAttendanceStatus(DateTime(2026, 1, 5, 6, 0)), 'Attend');
      expect(resolveAttendanceStatus(DateTime(2026, 1, 5, 7, 59)), 'Attend');
      expect(resolveAttendanceStatus(DateTime(2026, 1, 5, 8, 0)), 'Attend');
    });

    test('tepat pukul 08:30 masih Attend, 08:31 sudah Late', () {
      expect(resolveAttendanceStatus(DateTime(2026, 1, 5, 8, 30)), 'Attend');
      expect(resolveAttendanceStatus(DateTime(2026, 1, 5, 8, 31)), 'Late');
    });

    test('antara 09:00 sampai 17:59 terhitung Late', () {
      expect(resolveAttendanceStatus(DateTime(2026, 1, 5, 9, 0)), 'Late');
      expect(resolveAttendanceStatus(DateTime(2026, 1, 5, 17, 59)), 'Late');
    });

    test('pukul 18:00 ke atas dan dini hari terhitung Leave', () {
      expect(resolveAttendanceStatus(DateTime(2026, 1, 5, 18, 0)), 'Leave');
      expect(resolveAttendanceStatus(DateTime(2026, 1, 5, 23, 59)), 'Leave');
    });
  });
}
