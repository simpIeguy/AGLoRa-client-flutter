import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/tracker_status.dart';
import 'package:tsp_tracker/data/tracker_store.dart';
import 'package:tsp_tracker/protocol/tracker_point.dart';
import 'package:tsp_tracker/ui/format.dart';
import 'package:tsp_tracker/ui/theme.dart';
import 'package:tsp_tracker/util/geo.dart';

TrackerPoint point(String name, DateTime time, {double lat = 53.9}) =>
    TrackerPoint(identifier: name, latitude: lat, longitude: 27.5, time: time);

void main() {
  group('log of points (B2)', () {
    test('newest first, at most 50 per tracker', () {
      final store = TrackerStore();
      final start = DateTime.utc(2026, 10, 28, 12);
      for (int i = 0; i < 60; i++) {
        store.addPoint(point('Tracker2', start.add(Duration(seconds: i * 15)),
            lat: 53.0 + i / 1000));
      }
      store.addPoint(point('Tracker3', start));

      final log = store.pointsOf('Tracker2');
      expect(log, hasLength(TrackerStore.pointsPerTrackerLimit));
      expect(log.first.time, start.add(const Duration(seconds: 59 * 15)));
      expect(log.last.time, start.add(const Duration(seconds: 10 * 15)));
      for (int i = 1; i < log.length; i++) {
        expect(log[i - 1].time.isAfter(log[i].time), isTrue);
      }
      // the limit is per tracker
      expect(store.pointsOf('Tracker3'), hasLength(1));
      expect(
          store.latestPoints.firstWhere((t) => t.identifier == 'Tracker2').time,
          log.first.time);
    });

    test('an older point that comes late goes to its place', () {
      final store = TrackerStore();
      final t = DateTime.utc(2026, 10, 28, 12);
      store.addPoint(point('T', t));
      store.addPoint(point('T', t.subtract(const Duration(minutes: 1))));
      store.addPoint(point('T', t.add(const Duration(minutes: 1))));
      expect(store.pointsOf('T').map((p) => p.time.minute), [1, 0, 59]);
    });

    test('copied coordinates look like 53.902284, 27.561831', () {
      expect(formatCoordinates(53.902284, 27.561831), '53.902284, 27.561831');
      expect(formatCoordinates(-0.5, 7), '-0.500000, 7.000000');
    });
  });

  group('tracker status and color (B1)', () {
    final now = DateTime.now().toUtc();

    TrackerStatus statusAt(Duration age, {bool connected = false}) =>
        trackerStatus(
            time: now.subtract(age), isConnected: connected, now: now);

    test('by the age of the last point', () {
      expect(statusAt(const Duration(seconds: 30)), TrackerStatus.active);
      expect(statusAt(const Duration(minutes: 2)), TrackerStatus.fading);
      expect(statusAt(const Duration(minutes: 6)), TrackerStatus.lost);
    });

    test('the thresholds are 1 and 5 minutes', () {
      expect(trackerActiveTimeout, const Duration(minutes: 1));
      expect(trackerLostTimeout, const Duration(minutes: 5));
    });

    test('the connected tracker is blue whatever its age', () {
      expect(statusAt(const Duration(hours: 1), connected: true),
          TrackerStatus.connected);
    });

    test('text stays readable on every card color', () {
      for (final status in TrackerStatus.values) {
        final background = AppColors.status(status);
        final text = AppColors.readableOn(background);
        expect(_contrast(background, text), greaterThan(3.0),
            reason: '$status');
      }
    });
  });

  group('arrow to the tracker (V1)', () {
    test('compass off: the top of the phone is north', () {
      expect(arrowAngle(0, 0), closeTo(0, 1e-9));
      expect(arrowAngle(90, 0), closeTo(3.14159 / 2, 1e-4));
      expect(arrowAngle(180, 0), closeTo(3.14159, 1e-4));
      expect(arrowAngle(-90, 0), closeTo(3 * 3.14159 / 2, 1e-4));
    });

    test('compass on: turns against the phone', () {
      // phone looks east, the tracker is north: the arrow points left
      expect(arrowAngle(0, 90), closeTo(3 * 3.14159 / 2, 1e-4));
      // phone looks at the tracker: the arrow points up
      expect(arrowAngle(45, 45), closeTo(0, 1e-9));
    });

    test('compass points', () {
      expect(compassPoint(0), 'С');
      expect(compassPoint(79), 'В');
      expect(compassPoint(-100), 'З');
      expect(compassPoint(350), 'С');
      expect(normalizeDegrees(-90), 270);
      expect(formatBearing(-45), '315° СЗ');
    });
  });

  group('distance and direction from the phone', () {
    test('known pairs of points', () {
      // Minsk → Moscow, about 675 km to the east-north-east
      expect(distanceBetween(53.9023, 27.5618, 55.7558, 37.6173) / 1000,
          closeTo(675, 5));
      expect(
          bearingBetween(53.9023, 27.5618, 55.7558, 37.6173), closeTo(67, 2));
      // one degree of latitude is about 111.3 km, straight north
      expect(distanceBetween(53, 27, 54, 27), closeTo(111319, 100));
      expect(bearingBetween(53, 27, 54, 27), closeTo(0, 1e-9));
      expect(bearingBetween(54, 27, 53, 27), closeTo(180, 1e-9));
      expect(distanceBetween(53.9, 27.5, 53.9, 27.5), 0);
    });

    test('distance text', () {
      expect(formatDistance(0), '0 м');
      expect(formatDistance(999.4), '999 м');
      expect(formatDistance(1000), '1.0 км');
      expect(formatDistance(12345), '12.3 км');
    });

    test('age text', () {
      expect(formatAge(const Duration(seconds: 12)), '12 с назад');
      expect(formatAge(const Duration(minutes: 3)), '3 мин назад');
      expect(formatAge(const Duration(hours: 2)), '2 ч назад');
      expect(formatAge(const Duration(days: 4)), '4 дн назад');
      expect(formatAge(const Duration(seconds: -5)), '0 с назад');
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final bright = la > lb ? la : lb;
  final dark = la > lb ? lb : la;
  return (bright + 0.05) / (dark + 0.05);
}
