import 'package:aglora_client/aglora/data.dart';
import 'package:aglora_client/aglora/memory.dart';
import 'package:aglora_client/screens/screen_tracker_log.dart';
import 'package:aglora_client/utils/compass.dart';
import 'package:aglora_client/utils/tracker_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

AGLORATrackerPoint point(String name, DateTime time, {double lat = 53.9}) =>
    AGLORATrackerPoint(
        identifier: name, latitude: lat, longitude: 27.5, time: time);

void main() {
  setUp(resetApp);

  group('log of points (B2)', () {
    test('newest first, at most 50 per tracker', () {
      final start = DateTime.utc(2026, 10, 28, 12);
      for (int i = 0; i < 60; i++) {
        agloraAppMemory.addPoint(point(
            'Tracker2', start.add(Duration(seconds: i * 15)),
            lat: 53.0 + i / 1000));
      }
      agloraAppMemory.addPoint(point('Tracker3', start));

      final log = agloraAppMemory.pointsOf('Tracker2');
      expect(log, hasLength(pointsPerTrackerLimit));
      expect(log.first.time, start.add(Duration(seconds: 59 * 15)));
      expect(log.last.time, start.add(Duration(seconds: 10 * 15)));
      for (int i = 1; i < log.length; i++) {
        expect(log[i - 1].time.isAfter(log[i].time), isTrue);
      }
      // the limit is per tracker
      expect(agloraAppMemory.pointsOf('Tracker3'), hasLength(1));
      expect(
          agloraAppMemory.trackers
              .firstWhere((t) => t.identifier == 'Tracker2')
              .time,
          log.first.time);
    });

    test('copied coordinates look like 53.902284, 27.561831', () {
      expect(formatCoordinates(53.902284, 27.561831), '53.902284, 27.561831');
      expect(formatCoordinates(-0.5, 7), '-0.500000, 7.000000');
    });
  });

  group('tracker status and color (B1)', () {
    final now = DateTime.now().toUtc();

    test('by the age of the last point', () {
      expect(trackerStatusFor('T', now.subtract(Duration(seconds: 30))),
          TrackerStatus.active);
      expect(trackerStatusFor('T', now.subtract(Duration(minutes: 2))),
          TrackerStatus.fading);
      expect(trackerStatusFor('T', now.subtract(Duration(minutes: 6))),
          TrackerStatus.lost);
    });

    test('the thresholds are 1 and 5 minutes', () {
      expect(trackerActiveTimeout, Duration(minutes: 1));
      expect(trackerLostTimeout, Duration(minutes: 5));
    });

    test('the connected tracker is blue whatever its age', () {
      agloraAppMemory.setConnectedTracker('Tracker1');
      expect(trackerStatusFor('Tracker1', now.subtract(Duration(hours: 1))),
          TrackerStatus.connected);
      expect(trackerStatusFor('Tracker2', now), TrackerStatus.active);
    });

    test('text stays readable on every card color', () {
      for (final status in TrackerStatus.values) {
        final background = trackerStatusColor(status);
        final text = readableTextColor(background);
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
