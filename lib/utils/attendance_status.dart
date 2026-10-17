/// Aturan jam presensi dari Step 11 modul.
///
/// Dipisahkan dari widget agar logikanya bisa diuji tanpa membangun UI.
library;

/// Mengembalikan `Attend`, `Late`, atau `Leave` berdasarkan jam [now].
///
/// - Sebelum atau tepat pukul 08:30 → `Attend`
/// - 08:31 sampai sebelum pukul 18:00 → `Late`
/// - Selain itu → `Leave`
String resolveAttendanceStatus(DateTime now) {
  final dateHours = now.hour;
  final dateMinutes = now.minute;

  if (dateHours < 8 || (dateHours == 8 && dateMinutes <= 30)) {
    return "Attend";
  }
  if ((dateHours > 8 && dateHours < 18) ||
      (dateHours == 8 && dateMinutes >= 31)) {
    return "Late";
  }
  return "Leave";
}
