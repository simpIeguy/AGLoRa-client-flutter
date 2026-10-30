import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/track_export.dart';
import 'package:tsp_tracker/protocol/tracker_point.dart';

TrackerPoint at(int second, double lat, {String alt = '142.3'}) => TrackerPoint(
        identifier: 'UAV1',
        latitude: lat,
        longitude: 27.5,
        time: DateTime.utc(2026, 10, 30, 12, 0, second),
        sensors: [
          TrackerSensor(name: 'alt', value: alt),
          const TrackerSensor(name: 'sat', value: '9'),
        ]);

void main() {
  // the store keeps the newest first
  final track =
      ExportTrack(label: 'БЛА 1 <UAV1>', points: [at(30, 53.91), at(0, 53.9)]);

  test('GPX: one track, oldest point first, the name escaped', () {
    final gpx = tracksToGpx([track]);
    expect(gpx, contains('<name>БЛА 1 &lt;UAV1&gt;</name>'));
    expect(gpx.indexOf('lat="53.9"'), lessThan(gpx.indexOf('lat="53.91"')));
    expect(gpx, contains('<ele>142.3</ele>'));
    expect(gpx, contains('<time>2026-10-30T12:00:00.000Z</time>'));
  });

  test('GPX: no altitude, no <ele>; a tracker without points is left out', () {
    final gpx = tracksToGpx([
      ExportTrack(label: 'A', points: [at(0, 53.9, alt: '')]),
      const ExportTrack(label: 'B', points: []),
    ]);
    expect(gpx, isNot(contains('<ele>')));
    expect(gpx, isNot(contains('<name>B</name>')));
  });

  test('CSV: a header, a row per point, oldest first, quotes where needed', () {
    final lines = tracksToCsv([
      ExportTrack(label: 'Саша, "БЛА"', points: [at(30, 53.91), at(0, 53.9)])
    ]).split('\r\n');
    expect(
        lines[0], '﻿tracker,time_utc,latitude,longitude,altitude_m,satellites');
    expect(
        lines[1], '"Саша, ""БЛА""",2026-10-30T12:00:00.000Z,53.9,27.5,142.3,9');
    expect(lines[2], contains('53.91'));
    expect(lines[3], '');
  });
}
