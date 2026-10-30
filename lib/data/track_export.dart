import '../protocol/tracker_point.dart';

/// one tracker's points for a file: [label] is the name the user sees
class ExportTrack {
  const ExportTrack({required this.label, required this.points});

  final String label;

  /// as the store keeps them: the newest first
  final List<TrackerPoint> points;
}

/// GPX 1.1, opens in Mission Planner, OsmAnd, Google Earth, QGIS…: a track
/// per tracker, the points oldest first
String tracksToGpx(List<ExportTrack> tracks) {
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="Поиск БЛА" '
        'xmlns="http://www.topografix.com/GPX/1/1">');
  for (final track in tracks) {
    if (track.points.isEmpty) continue;
    out
      ..writeln('  <trk>')
      ..writeln('    <name>${_xml(track.label)}</name>')
      ..writeln('    <trkseg>');
    for (final p in track.points.reversed) {
      final alt = double.tryParse(p.sensor('alt') ?? '');
      out.write('      <trkpt lat="${p.latitude}" lon="${p.longitude}">');
      if (alt != null && alt.isFinite) out.write('<ele>$alt</ele>');
      out.writeln('<time>${p.time.toUtc().toIso8601String()}</time></trkpt>');
    }
    out
      ..writeln('    </trkseg>')
      ..writeln('  </trk>');
  }
  out.writeln('</gpx>');
  return out.toString();
}

/// CSV for a spreadsheet: a byte order mark first, so Excel reads Russian
/// names right; time is the GPS time, UTC
String tracksToCsv(List<ExportTrack> tracks) {
  final out = StringBuffer('﻿')
    ..write('tracker,time_utc,latitude,longitude,altitude_m,satellites\r\n');
  for (final track in tracks) {
    for (final p in track.points.reversed) {
      out.write([
        _csv(track.label),
        p.time.toUtc().toIso8601String(),
        p.latitude,
        p.longitude,
        _csv(p.sensor('alt') ?? ''),
        _csv(p.sensor('sat') ?? ''),
      ].join(','));
      out.write('\r\n');
    }
  }
  return out.toString();
}

String _xml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _csv(String text) => text.contains(RegExp(r'[",\r\n]'))
    ? '"${text.replaceAll('"', '""')}"'
    : text;
