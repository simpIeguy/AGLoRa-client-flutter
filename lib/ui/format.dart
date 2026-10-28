import '../util/geo.dart';

/// "53.902284, 27.561831": map apps understand it when pasted
String formatCoordinates(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

/// "850 м", "1.2 км"
String formatDistance(double metres) {
  final m = metres.round();
  if (m < 1000) return '$m м';
  return '${(m ~/ 100 / 10).toStringAsFixed(1)} км';
}

/// "12 с назад", "3 мин назад", "2 ч назад", "4 дн назад"
String formatAge(Duration age) {
  if (age.isNegative) age = Duration.zero;
  if (age.inMinutes < 1) return '${age.inSeconds} с назад';
  if (age.inHours < 1) return '${age.inMinutes} мин назад';
  if (age.inDays < 1) return '${age.inHours} ч назад';
  return '${age.inDays} дн назад';
}

/// 24-hour clock, "07:05:09"
String formatClock(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

const List<String> _compassPoints = [
  'С',
  'СВ',
  'В',
  'ЮВ',
  'Ю',
  'ЮЗ',
  'З',
  'СЗ'
];

/// 8-point compass name of a direction in degrees
String compassPoint(num degrees) =>
    _compassPoints[((normalizeDegrees(degrees.toDouble()) + 22.5) ~/ 45) % 8];

/// "45° СВ"
String formatBearing(double bearing) {
  final degrees = normalizeDegrees(bearing).round() % 360;
  return '$degrees° ${compassPoint(degrees)}';
}
