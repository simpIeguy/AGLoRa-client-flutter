import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/util/coordinate_parser.dart';
import 'package:tsp_tracker/util/sk42.dart';

void main() {
  void expectAt(String text, double lat, double lon,
      {CoordinateKind? kind, double tolerance = 1e-5, int? zone}) {
    final p = parseCoordinates(text, defaultZone: zone);
    expect(p, isNotNull, reason: text);
    expect(p!.latitude, closeTo(lat, tolerance), reason: text);
    expect(p.longitude, closeTo(lon, tolerance), reason: text);
    if (kind != null) expect(p.kind, kind, reason: text);
  }

  group('WGS 84, degrees', () {
    test('decimal, the usual ways to write it', () {
      for (final text in [
        '53.9023, 27.5618',
        '53.9023,27.5618',
        '53,9023, 27,5618',
        '53,9023 27,5618',
        '53.9023 27.5618',
        '53.9023;27.5618',
        '  53.9023°, 27.5618°  ',
        'N 53.9023 E 27.5618',
        '53.9023 N, 27.5618 E',
        '53.9023 с.ш. 27.5618 в.д.'
            .replaceAll('с.ш.', 'С')
            .replaceAll('в.д.', 'В'),
      ]) {
        expectAt(text, 53.9023, 27.5618, kind: CoordinateKind.decimal);
      }
    });

    test('signs and hemispheres', () {
      expectAt('-33.8688, 151.2093', -33.8688, 151.2093);
      expectAt('33.8688 S 151.2093 E', -33.8688, 151.2093);
      expectAt('40.7128 N 74.0060 W', 40.7128, -74.0060);
      expectAt('40.7128, -74.0060', 40.7128, -74.0060);
    });

    test('longitude first: by the letters, or by a first number over 90', () {
      expectAt('E 27.5618 N 53.9023', 53.9023, 27.5618);
      expectAt('27.5618 E 53.9023 N', 53.9023, 27.5618);
      expectAt('151.2093, -33.8688', -33.8688, 151.2093);
    });

    test('degrees, minutes, seconds', () {
      // 53°54'08.28" = 53.9023, 27°33'42.48" = 27.5618
      expectAt('53°54\'08.28"N 27°33\'42.48"E', 53.9023, 27.5618,
          kind: CoordinateKind.degreesMinutesSeconds);
      expectAt('N 53 54 08.28 E 27 33 42.48', 53.9023, 27.5618);
      expectAt('53 54 08.28 N 27 33 42.48 E', 53.9023, 27.5618);
      expectAt(
          '53°54′08.28″ с.ш. 27°33′42.48″ в.д.'
              .replaceAll('с.ш.', 'С')
              .replaceAll('в.д.', 'В'),
          53.9023,
          27.5618);
    });

    test('degrees and decimal minutes', () {
      // 53°54.138' = 53.9023, 27°33.708' = 27.5618
      expectAt('53°54.138\' N 27°33.708\' E', 53.9023, 27.5618,
          kind: CoordinateKind.degreesMinutes);
      expectAt('N53 54.138 E027 33.708', 53.9023, 27.5618);
    });

    test('nonsense is not understood', () {
      for (final text in [
        '',
        'привет',
        '53.9023',
        '53.9023, 27.5618, 5',
        '95.0, 127.0',
        '53.9, 200.0',
        '53 75 00, 27 10 00',
        '53.5 54 08, 27 33 42',
        'N 53 E 27 S',
      ]) {
        expect(parseCoordinates(text), isNull, reason: text);
      }
    });
  });

  group('СК-42, rectangular', () {
    // Minsk, 53.9 N 27.56 E: the way there, then back
    final minsk = wgs84ToGaussKruger(53.9, 27.56);

    test('the way back is the way there', () {
      final back = gaussKrugerToWgs84(minsk.x, minsk.y);
      expect(back.latitude, closeTo(53.9, 1e-6));
      expect(back.longitude, closeTo(27.56, 1e-6));
      for (final (lat, lon) in [
        (0.5, 0.5),
        (45.0, 37.6),
        (55.75, 37.62),
        (68.97, 33.07),
        (43.1, 131.9),
      ]) {
        final gk = wgs84ToGaussKruger(lat, lon);
        final p = gaussKrugerToWgs84(gk.x, gk.y);
        expect(p.latitude, closeTo(lat, 1e-6), reason: '$lat $lon');
        expect(p.longitude, closeTo(lon, 1e-6), reason: '$lat $lon');
      }
    });

    test('the datum shift back and forth', () {
      final sk = wgs84ToSk42(53.9, 27.56);
      final back = sk42ToWgs84(sk.latitude, sk.longitude);
      expect(back.latitude, closeTo(53.9, 1e-7));
      expect(back.longitude, closeTo(27.56, 1e-7));
    });

    test('the ways to write it', () {
      final x = minsk.x.round(), y = minsk.y.round();
      for (final text in [
        'X $x Y $y',
        'X=$x, Y=$y',
        'x: $x; y: $y',
        'Х $x У $y',
        '$x $y',
        '$x, $y',
        'X ${_spaced(x)} Y ${_spaced(y)}',
        'Y $y X $x',
      ]) {
        expectAt(text, 53.9, 27.56,
            kind: CoordinateKind.gaussKruger, tolerance: 2e-5);
      }
      expect(parseCoordinates('X $x Y $y')!.zone, 5);
    });

    test('without the zone number: the map\'s zone is taken, and said so', () {
      final x = minsk.x.round(), y = minsk.y.round() - 5000000;
      expect(parseCoordinates('X $x Y $y'), isNull);
      final p = parseCoordinates('X $x Y $y', defaultZone: 5)!;
      expect(p.zoneGuessed, isTrue);
      expect(p.latitude, closeTo(53.9, 2e-5));
      expect(p.longitude, closeTo(27.56, 2e-5));
      expect(
          parseCoordinates('X ${minsk.x.round()} Y ${minsk.y.round()}',
                  defaultZone: 7)!
              .zoneGuessed,
          isFalse);
    });
  });
}

String _spaced(int v) => v
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
