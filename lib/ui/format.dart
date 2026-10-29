import '../util/geo.dart';

/// how the coordinates are written, a choice in the settings
enum CoordinateFormat {
  /// "53.90228, 27.56183", as in Google Maps and OsmAnd
  decimal,

  /// "53°54′08″N 27°33′42″E"
  dms,
}

/// "53.90228, 27.56183": 5 digits are about a metre; map apps understand it
/// when pasted. Or degrees, minutes, seconds.
String formatCoordinates(double latitude, double longitude,
        [CoordinateFormat format = CoordinateFormat.decimal]) =>
    switch (format) {
      CoordinateFormat.decimal =>
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      CoordinateFormat.dms =>
        '${_dms(latitude, 'N', 'S')} ${_dms(longitude, 'E', 'W')}',
    };

/// 53.90228 → 53°54′08″N; a second is about 30 m
String _dms(double degrees, String plus, String minus) {
  final seconds = (degrees.abs() * 3600).round();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${seconds ~/ 3600}°${two(seconds ~/ 60 % 60)}′${two(seconds % 60)}″'
      '${degrees < 0 ? minus : plus}';
}

/// the number and the unit apart: the card shows the number large
({String value, String unit}) distanceParts(double metres) {
  // "not a number" must not turn a screen into an error
  if (!metres.isFinite) return (value: '—', unit: 'м');
  final m = metres.round();
  if (m < 1000) return (value: '$m', unit: 'м');
  // tenths below 10 km, whole kilometres further
  final km = m < 10000 ? (m ~/ 100 / 10).toStringAsFixed(1) : '${m ~/ 1000}';
  return (value: km.replaceAll('.', ','), unit: 'км');
}

/// "850 м", "1,2 км", "12 км"
String formatDistance(double metres) {
  final d = distanceParts(metres);
  return '${d.value} ${d.unit}';
}

/// "12 с", "3 мин", "2 ч", "4 дн"
String formatDuration(Duration age) {
  if (age.isNegative) age = Duration.zero;
  if (age.inMinutes < 1) return '${age.inSeconds} с';
  if (age.inHours < 1) return '${age.inMinutes} мин';
  if (age.inDays < 1) return '${age.inHours} ч';
  return '${age.inDays} дн';
}

/// "12 с назад", "3 мин назад", "2 ч назад", "4 дн назад"
String formatAge(Duration age) => '${formatDuration(age)} назад';

/// 24-hour clock, "07:05:09"
String formatClock(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

// clockwise from north, 22.5° each
const List<String> _compassPoints = [
  'С', 'ССВ', 'СВ', 'ВСВ', 'В', 'ВЮВ', 'ЮВ', 'ЮЮВ', //
  'Ю', 'ЮЮЗ', 'ЮЗ', 'ЗЮЗ', 'З', 'ЗСЗ', 'СЗ', 'ССЗ',
];

/// 16-point compass name of a direction in degrees, "ВСВ"
String compassPoint(num degrees) => _compassPoints[
    ((normalizeDegrees(degrees.toDouble()) + 11.25) ~/ 22.5) % 16];

/// "79° ВСВ"
String formatBearing(double bearing) {
  final degrees = normalizeDegrees(bearing).round() % 360;
  return '$degrees° ${compassPoint(degrees)}';
}
