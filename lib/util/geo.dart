import 'dart:math';

/// mean Earth radius, metres (the same as Geolocator.distanceBetween uses)
const double earthRadius = 6378137.0;

double _radians(double degrees) => degrees * pi / 180;

/// great-circle distance between two points, metres (haversine)
double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) +
      cos(_radians(lat1)) * cos(_radians(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * earthRadius * asin(sqrt(a));
}

/// initial direction from the first point to the second, degrees
/// clockwise from north, 0 <= result < 360
double bearingBetween(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = _radians(lat1);
  final phi2 = _radians(lat2);
  final dLon = _radians(lon2 - lon1);
  final y = sin(dLon) * cos(phi2);
  final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLon);
  return normalizeDegrees(atan2(y, x) * 180 / pi);
}

/// any angle in degrees to 0 <= result < 360
double normalizeDegrees(double degrees) => (degrees % 360 + 360) % 360;

/// rotation (radians, clockwise) of an "up" arrow so it points at a target:
/// [bearing] is the direction to the target, [phoneHeading] is where the top
/// of the phone points (0 when the compass is off: the top is taken as north)
double arrowAngle(double bearing, double phoneHeading) =>
    normalizeDegrees(bearing - phoneHeading) * pi / 180;
