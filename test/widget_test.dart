// Smoke test untuk HomeScreen. HomeScreen sengaja diuji langsung, bukan lewat
// AttendanceApp, karena main() menginisialisasi Firebase yang tidak tersedia di
// lingkungan test.

import 'package:attendance_app/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeScreen menampilkan empat menu utama',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Attendance Record'), findsOneWidget);
    expect(find.text('Permission / Leave'), findsOneWidget);
    expect(find.text('Attendance History'), findsOneWidget);
    expect(find.text('Data Wajah Siswa'), findsOneWidget);
    expect(find.text('IDN Boarding School Solo'), findsOneWidget);
  });

  testWidgets('menu data wajah siswa ditandai terkunci',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Gemboknya harus terlihat sebelum diketuk, bukan baru ketahuan setelah
    // PIN diminta.
    expect(find.text('Khusus guru — perlu PIN admin'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('menu presensi tidak lagi menawarkan input nama',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Nama kini berasal dari pengenalan wajah, jadi subtitle-nya harus
    // menjelaskan itu dan layar awal tidak boleh punya field teks apa pun.
    expect(
      find.text('Wajah Anda dikenali otomatis, tanpa isi nama'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });
}
