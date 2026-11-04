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

/// СК-42 rectangular coordinates (Gauss–Krüger, 6° zones), metres: [x] to the
/// north, [y] with the zone number in front and 500 km added to the east.
typedef GaussKrugerPosition = ({double x, double y, int zone});

double _asinh(double v) => log(v + sqrt(v * v + 1));
double _atanh(double v) => 0.5 * log((1 + v) / (1 - v));
double _sinh(double v) => (exp(v) - exp(-v)) / 2;
double _cosh(double v) => (exp(v) + exp(-v)) / 2;

/// WGS 84 → СК-42 → Gauss–Krüger on the Krasovsky ellipsoid. The projection
/// is exact (Krüger series); the error comes from the datum shift, a few
/// metres. Not for surveying.
GaussKrugerPosition wgs84ToGaussKruger(double latitude, double longitude) {
  final sk = wgs84ToSk42(latitude, longitude);
  // zone 1 is 0–6° E, the central meridian is 6 * zone - 3
  final number = (sk.longitude / 6).floor() + 1;
  final middle = (6 * number - 3) * pi / 180;
  final phi = sk.latitude * pi / 180;
  final dl = sk.longitude * pi / 180 - middle;

  const n = _krasF / (2 - _krasF);
  final a = _krasA / (1 + n) * (1 + n * n / 4 + pow(n, 4) / 64);
  final alpha = [
    n / 2 - 2 * n * n / 3 + 5 * pow(n, 3) / 16 + 41 * pow(n, 4) / 180,
    13 * n * n / 48 - 3 * pow(n, 3) / 5 + 557 * pow(n, 4) / 1440,
    61 * pow(n, 3) / 240 - 103 * pow(n, 4) / 140,
    49561 * pow(n, 4) / 161280,
  ];
  final q = 2 * sqrt(n) / (1 + n);
  final t = _sinh(_atanh(sin(phi)) - q * _atanh(q * sin(phi)));
  final xi0 = atan2(t, cos(dl));
  final eta0 = _asinh(sin(dl) / sqrt(t * t + cos(dl) * cos(dl)));
  var xi = xi0;
  var eta = eta0;
  for (var j = 1; j <= 4; j++) {
    xi += alpha[j - 1] * sin(2 * j * xi0) * _cosh(2 * j * eta0);
    eta += alpha[j - 1] * cos(2 * j * xi0) * _sinh(2 * j * eta0);
  }
  return (
    x: a * xi,
    y: number * 1e6 + 500000 + a * eta,
    zone: number,
  );
}

/// "X 6012345, Y 4512345": whole metres
String formatGaussKruger(GaussKrugerPosition p) =>
    'X ${p.x.round()}, Y ${p.y.round()}';

/// СК-42 geographic degrees → WGS 84, ground level: the set of numbers above
/// applied forward. The reverse of [wgs84ToSk42] to a fraction of a metre.
Sk42Position sk42ToWgs84(double latitude, double longitude) {
  final lat = latitude * pi / 180;
  final lon = longitude * pi / 180;

  // Krasovsky geographic → geocentric XYZ
  const e2k = _krasF * (2 - _krasF);
  final nk = _krasA / sqrt(1 - e2k * pow(sin(lat), 2));
  final xp = nk * cos(lat) * cos(lon);
  final yp = nk * cos(lat) * sin(lon);
  final zp = nk * (1 - e2k) * sin(lat);

  // the shift, the turn and the scale: Xw = T + (1 + s) * R * Xp
  const k = 1 + _scale;
  final x = _dx + k * (xp - _rz * yp + _ry * zp);
  final y = _dy + k * (_rz * xp + yp);
  final z = _dz + k * (-_ry * xp + zp);

  // geocentric XYZ → geographic on the WGS 84 ellipsoid
  const e2 = _wgsF * (2 - _wgsF);
  final p = sqrt(x * x + y * y);
  var phi = atan2(z, p * (1 - e2));
  for (var i = 0; i < 6; i++) {
    final n = _wgsA / sqrt(1 - e2 * pow(sin(phi), 2));
    phi = atan2(z + e2 * n * sin(phi), p);
  }
  return (latitude: phi * 180 / pi, longitude: atan2(y, x) * 180 / pi);
}

/// Gauss–Krüger of СК-42 (northern hemisphere) → WGS 84 degrees. [y] has the
/// zone number in front, as [wgs84ToGaussKruger] gives it. The Krüger series
/// back; the same few metres of the datum shift as the way there.
Sk42Position gaussKrugerToWgs84(double x, double y) {
  final zone = (y / 1e6).floor();
  final middle = (6 * zone - 3) * pi / 180;

  const n = _krasF / (2 - _krasF);
  final a = _krasA / (1 + n) * (1 + n * n / 4 + pow(n, 4) / 64);
  final beta = [
    n / 2 - 2 * n * n / 3 + 37 * pow(n, 3) / 96 - pow(n, 4) / 360,
    n * n / 48 + pow(n, 3) / 15 - 437 * pow(n, 4) / 1440,
    17 * pow(n, 3) / 480 - 37 * pow(n, 4) / 840,
    4397 * pow(n, 4) / 161280,
  ];
  final delta = [
    2 * n - 2 * n * n / 3 - 2 * pow(n, 3) + 116 * pow(n, 4) / 45,
    7 * n * n / 3 - 8 * pow(n, 3) / 5 - 227 * pow(n, 4) / 45,
    56 * pow(n, 3) / 15 - 136 * pow(n, 4) / 35,
    4279 * pow(n, 4) / 630,
  ];
  final xi = x / a;
  final eta = (y - zone * 1e6 - 500000) / a;
  var xi1 = xi;
  var eta1 = eta;
  for (var j = 1; j <= 4; j++) {
    xi1 -= beta[j - 1] * sin(2 * j * xi) * _cosh(2 * j * eta);
    eta1 -= beta[j - 1] * cos(2 * j * xi) * _sinh(2 * j * eta);
  }
  final chi = asin(sin(xi1) / _cosh(eta1));
  var phi = chi;
  for (var j = 1; j <= 4; j++) {
    phi += delta[j - 1] * sin(2 * j * chi);
  }
  final lambda = middle + atan2(_sinh(eta1), cos(xi1));
  return sk42ToWgs84(phi * 180 / pi, lambda * 180 / pi);
}
