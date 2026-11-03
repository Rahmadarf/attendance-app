import 'package:attendance_app/core/errors.dart';
import 'package:attendance_app/services/admin_pin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late DateTime now;
  late AdminPin pin;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 11, 3, 8);
    pin = AdminPin(prefs, now: () => now);
  });

  test('not set until created; stored hashed, never in clear', () async {
    expect(pin.isSet, isFalse);
    await pin.set('2468');
    expect(pin.isSet, isTrue);
    expect(prefs.getKeys().any((k) => prefs.get(k) == '2468'), isFalse);
  });

  test('rejects short or non-numeric PIN', () {
    expect(pin.set('12'), throwsA(isA<AppException>()));
    expect(pin.set('abcd'), throwsA(isA<AppException>()));
  });

  test('right PIN passes, wrong fails', () async {
    await pin.set('2468');
    expect(await pin.verify('2468'), isTrue);
    expect(await pin.verify('0000'), isFalse);
  });

  test('5 wrong attempts lock for 30s, then it unlocks', () async {
    await pin.set('2468');
    for (var i = 0; i < AdminPin.maxAttempts; i++) {
      expect(await pin.verify('0000'), isFalse);
    }
    expect(pin.lockRemaining, isNotNull);
    // Even the right PIN is refused while locked.
    expect(pin.verify('2468'), throwsA(isA<AppException>()));

    now = now.add(const Duration(seconds: 31));
    expect(pin.lockRemaining, isNull);
    expect(await pin.verify('2468'), isTrue);
  });

  test('a correct PIN resets the failure count', () async {
    await pin.set('2468');
    for (var i = 0; i < AdminPin.maxAttempts - 1; i++) {
      await pin.verify('0000');
    }
    expect(await pin.verify('2468'), isTrue);
    // Count restarted: 4 more wrong attempts do not lock.
    for (var i = 0; i < AdminPin.maxAttempts - 1; i++) {
      await pin.verify('0000');
    }
    expect(pin.lockRemaining, isNull);
  });
}
