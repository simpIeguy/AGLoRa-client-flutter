import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/util/geo.dart';
import 'package:tsp_tracker/util/sk42.dart';

void main() {
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
