import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/store.dart';
import 'providers/people_provider.dart';
import 'repositories/attendance_repo.dart';
import 'repositories/leave_repo.dart';
import 'repositories/person_repo.dart';
import 'screens/kiosk_home_screen.dart';
import 'services/admin_pin.dart';
import 'services/face_camera.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(AttendanceApp(prefs: prefs));
}

class AttendanceApp extends StatelessWidget {
  final SharedPreferences prefs;

  /// Overrides for tests.
  final FaceCamera Function()? cameraFactory;
  final Duration? pollInterval;

  const AttendanceApp({
    super.key,
    required this.prefs,
    this.cameraFactory,
    this.pollInterval,
  });

  @override
  Widget build(BuildContext context) {
    final store = JsonStore(prefs);
    final leaves = LeaveRepo(store);

    return MultiProvider(
      providers: [
        Provider.value(value: leaves),
        Provider.value(value: AttendanceRepo(store, leaves)),
        Provider.value(value: AdminPin(prefs)),
        ChangeNotifierProvider(
          // Not lazy: the list must be loaded before the first scan.
          lazy: false,
          create: (_) => PeopleProvider(PersonRepo(store))..refresh(),
        ),
      ],
      child: MaterialApp(
        title: 'Absensi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: KioskHomeScreen(
          cameraFactory: cameraFactory,
          pollInterval: pollInterval,
        ),
      ),
    );
  }
}
