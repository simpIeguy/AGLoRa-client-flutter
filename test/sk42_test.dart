import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/util/geo.dart';
import 'package:tsp_tracker/util/sk42.dart';

void main() {
  gaussKrugerTests();
  test('СК-42 differs from WGS 84 by 100–200 m, east in the longitude', () {
    for (final (lat, lon) in [(53.9, 27.56), (55.75, 37.62), (45.0, 40.0)]) {
      final sk = wgs84ToSk42(lat, lon);
      final shift = distanceBetween(lat, lon, sk.latitude, sk.longitude);
      expect(shift, inInclusiveRange(100, 200), reason: '$lat $lon');
      // the usual picture: Pulkovo longitudes run a little larger
      expect(sk.longitude - lon, inInclusiveRange(0.001, 0.0035));
      expect((sk.latitude - lat).abs(), lessThan(0.002));
    }
  });

  test('the same input gives the same answer, no NaN near the poles of range',
      () {
    final a = wgs84ToSk42(53.9, 27.56);
    expect(a, wgs84ToSk42(53.9, 27.56));
    expect(wgs84ToSk42(0, 0).latitude.isFinite, isTrue);
    expect(wgs84ToSk42(-30, -60).longitude.isFinite, isTrue);
  });
}

void gaussKrugerTests() {
  test('Gauss–Krüger: zone, the central meridian, the meridian arc', () {
    // 53.9°N 27.56°E is in zone 5 (24–30°E), centre 27°E
    final minsk = wgs84ToGaussKruger(53.9, 27.56);
    expect(minsk.zone, 5);
    expect(minsk.y, inInclusiveRange(5530000, 5545000));
    expect(minsk.x, inInclusiveRange(5.97e6, 5.99e6));

    // far from the datum shift's reach, the arc to 55°N is about 6.10e6 m
    final north = wgs84ToGaussKruger(55, 27);
    expect(north.x, inInclusiveRange(6.09e6, 6.11e6));
    // on the central meridian the easting is the zone's 500 km (± the shift)
    expect(north.y - 5500000, inInclusiveRange(-400, 400));

    expect(formatGaussKruger(minsk), startsWith('X 59'));
    expect(wgs84ToGaussKruger(0, 0.5).x.abs(), lessThan(400));
  });
}
