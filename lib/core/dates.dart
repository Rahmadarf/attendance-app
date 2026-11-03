import 'package:intl/intl.dart';

final _dateKey = DateFormat('yyyy-MM-dd');

/// Storage format for a calendar day.
String dateKey(DateTime d) => _dateKey.format(d);

DateTime parseDateKey(String s) => _dateKey.parseStrict(s);
