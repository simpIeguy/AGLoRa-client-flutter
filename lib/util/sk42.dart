import 'dart:math';

/// A position in the СК-42 (Pulkovo 1942) datum, degrees.
typedef Sk42Position = ({double latitude, double longitude});

const double _wgsA = 6378137;
const double _wgsF = 1 / 298.257223563;
const double _krasA = 6378245; // the Krasovsky ellipsoid of СК-42
const double _krasF = 1 / 298.3;

// СК-42 → WGS 84, the usual set (EPSG 1267, PROJ towgs84 for Pulkovo 1942;
// GOST gives the same numbers): shifts in metres, turns in arc seconds,
// scale in parts per unit
const double _dx = 23.92;
const double _dy = -141.27;
const double _dz = -80.9;
const double _ry = 0.35 * pi / 648000;
const double _rz = 0.82 * pi / 648000;
const double _scale = -0.12e-6;

/// WGS 84 → СК-42 as geographic degrees, ground level. This is the reverse
/// of the set above. It is good to a few metres, as the set itself is: for
/// a tracker search that is enough; it is not for surveying.
Sk42Position wgs84ToSk42(double latitude, double longitude) {
  final lat = latitude * pi / 180;
  final lon = longitude * pi / 180;

  // WGS 84 → geocentric XYZ
  const e2w = _wgsF * (2 - _wgsF);
  final nw = _wgsA / sqrt(1 - e2w * pow(sin(lat), 2));
  final x = nw * cos(lat) * cos(lon) - _dx;
  final y = nw * cos(lat) * sin(lon) - _dy;
  final z = nw * (1 - e2w) * sin(lat) - _dz;

  // the turn and the scale back: Xp = (1 - s) * Rᵀ * (Xw - T)
  const k = 1 - _scale;
  final xp = k * (x + _rz * y - _ry * z);
  final yp = k * (-_rz * x + y);
  final zp = k * (_ry * x + z);

  // geocentric XYZ → geographic on the Krasovsky ellipsoid
  const e2 = _krasF * (2 - _krasF);
  final p = sqrt(xp * xp + yp * yp);
  var phi = atan2(zp, p * (1 - e2));
  for (var i = 0; i < 6; i++) {
    final n = _krasA / sqrt(1 - e2 * pow(sin(phi), 2));
    phi = atan2(zp + e2 * n * sin(phi), p);
  }
  return (latitude: phi * 180 / pi, longitude: atan2(yp, xp) * 180 / pi);
}
