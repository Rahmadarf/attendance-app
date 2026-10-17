// Smoke test untuk HomeScreen. HomeScreen sengaja diuji langsung, bukan lewat
// AttendanceApp, karena main() menginisialisasi Firebase yang tidak tersedia di
// lingkungan test.

import 'package:attendance_app/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeScreen menampilkan tiga menu utama',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Attendance Record'), findsOneWidget);
    expect(find.text('Permission / Leave'), findsOneWidget);
    expect(find.text('Attendance History'), findsOneWidget);
    expect(find.text('IDN Boarding School Solo'), findsOneWidget);
  });
}
