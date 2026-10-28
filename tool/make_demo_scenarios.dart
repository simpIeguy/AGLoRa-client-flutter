// Builds the demo-mode scenarios (assets/demo/*.txt) from a recorded NMEA
// track. Messages follow the current firmware: AGLORA::sendPackageToBLE and
// sendToPhone() in full-stack/src, "AGLoRa-" prefix, "\r\n" at the end.
// ignore_for_file: avoid_print (a command-line tool reports to the console)
//
//   cd client-app
//   dart run tool/make_demo_scenarios.dart ../emulator/src/main/resources/data/round1.txt assets/demo

import 'dart:io';

import 'package:tsp_tracker/demo/demo_scenario.dart' show escapeLineBreaks;

/// the firmware sends its own location every DATA_SENDING_INTERVAL; the demo
/// uses a shorter interval so the movement is easier to see
const int sendIntervalS = 15;

/// a point received over LoRa reaches the app this much later
const int loraLagMs = 1500;

/// own point goes to BLE right after lora.send()
const int ownLagMs = 300;

class Fix {
  Fix(this.time, this.lat, this.lon, this.alt, this.sats);
  final DateTime time;
  final double lat;
  final double lon;
  final double alt;
  final int sats;
}

bool _checksumOk(String line) {
  final star = line.lastIndexOf('*');
  if (!line.startsWith(r'$') || star < 0 || star + 3 > line.length) {
    return false;
  }
  int sum = 0;
  for (final c in line.substring(1, star).codeUnits) {
    sum ^= c;
  }
  return sum == int.tryParse(line.substring(star + 1, star + 3), radix: 16);
}

double _coordinate(String value, String hemisphere, int degreeDigits) {
  final degrees = double.parse(value.substring(0, degreeDigits));
  final minutes = double.parse(value.substring(degreeDigits));
  final result = degrees + minutes / 60;
  return (hemisphere == 'S' || hemisphere == 'W') ? -result : result;
}

List<Fix> readNmea(String path) {
  final altitudes = <String, double>{};
  final satellites = <String, int>{};
  final rmc = <List<String>>[];

  for (final raw in File(path).readAsLinesSync()) {
    final line = raw.trim();
    if (!_checksumOk(line)) continue;
    final f = line.substring(0, line.lastIndexOf('*')).split(',');
    if (f[0] == r'$GPGGA' && f.length > 9) {
      final key = f[1].split('.').first;
      altitudes[key] = double.tryParse(f[9]) ?? 0;
      satellites[key] = int.tryParse(f[7]) ?? 0;
    } else if (f[0] == r'$GPRMC' && f.length > 9 && f[2] == 'A') {
      rmc.add(f);
    }
  }

  final fixes = <Fix>[];
  for (final f in rmc) {
    final t = f[1];
    final d = f[9];
    final time = DateTime.utc(
      2000 + int.parse(d.substring(4, 6)),
      int.parse(d.substring(2, 4)),
      int.parse(d.substring(0, 2)),
      int.parse(t.substring(0, 2)),
      int.parse(t.substring(2, 4)),
      int.parse(t.substring(4, 6)),
    );
    final key = t.split('.').first;
    fixes.add(Fix(
      time,
      _coordinate(f[3], f[4], 2),
      _coordinate(f[5], f[6], 3),
      altitudes[key] ?? 0,
      satellites[key] ?? 0,
    ));
  }
  return fixes;
}

class Track {
  Track(this.fixes);
  final List<Fix> fixes;

  DateTime get start => fixes.first.time;
  int get durationS => fixes.last.time.difference(start).inSeconds;

  /// position [atS] seconds from the start, the track loops
  Fix at(int atS) {
    final target = start.add(Duration(seconds: atS % durationS));
    return fixes.firstWhere((f) => !f.time.isBefore(target),
        orElse: () => fixes.last);
  }
}

String _timestamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}Z';
}

/// [stored]: a point of another tracker, kept in memory and sent with
/// &index and &crc; own points have neither (sendMyPackageToBLE)
String pointMessage(String name, double lat, double lon, DateTime time,
    double alt, int sats, int battery,
    {required bool stored}) {
  return 'AGLoRa-point&ver=2.3&dev_batt=100'
      '&name=$name'
      '&lat=${lat.toStringAsFixed(6)}&lon=${lon.toStringAsFixed(6)}'
      '&timestamp=${_timestamp(time)}'
      '&gpsValid=1&sat=$sats&alt=${alt.toStringAsFixed(1)}'
      '&battery=$battery&dev_bat=100'
      '${stored ? '&index=#&crc=ok' : ''}\r\n';
}

class Event {
  Event(this.atMs, this.text);
  final int atMs;
  final String text;
}

class TrackerPlan {
  TrackerPlan(this.name,
      {this.fromS = 0,
      this.toS,
      this.phaseS = 0,
      this.offsetS = 0,
      this.dLat = 0,
      this.dLon = 0,
      this.own = false});

  final String name;
  final int fromS;
  final int? toS;

  /// where on the track it starts
  final int phaseS;

  /// when inside the send interval its fixes happen
  final int offsetS;
  final double dLat;
  final double dLon;
  final bool own;
}

List<Event> trackerEvents(Track track, TrackerPlan plan, int scenarioS) {
  final events = <Event>[];
  final toS = plan.toS ?? scenarioS;
  for (int s = plan.fromS + plan.offsetS; s <= toS; s += sendIntervalS) {
    final fix = track.at(s + plan.phaseS);
    final time = track.start.add(Duration(seconds: s));
    final battery = 100 - s ~/ 120;
    events.add(Event(
      s * 1000 + (plan.own ? ownLagMs : loraLagMs),
      pointMessage(plan.name, fix.lat + plan.dLat, fix.lon + plan.dLon, time,
          fix.alt + 40, fix.sats, battery,
          stored: !plan.own),
    ));
  }
  return events;
}

List<Event> plannedEvents(Track track, List<TrackerPlan> plans, int scenarioS) {
  final events = [
    for (final plan in plans) ...trackerEvents(track, plan, scenarioS)
  ];
  events.sort((a, b) => a.atMs.compareTo(b.atMs));
  return events;
}

/// pieces, glued messages, garbage: what a weak BLE link may deliver
List<Event> raggedEvents(List<Event> whole) {
  final out = <Event>[];
  for (int i = 0; i < whole.length; i++) {
    final e = whole[i];
    final text = e.text;
    switch (i) {
      case 1: // one message in three pieces, with pauses
        final a = text.length ~/ 3;
        out.add(Event(e.atMs, text.substring(0, a)));
        out.add(Event(e.atMs + 200, text.substring(a, 2 * a)));
        out.add(Event(e.atMs + 400, text.substring(2 * a)));
        break;
      case 3: // two messages glued into one chunk
        if (i + 1 < whole.length) {
          out.add(Event(e.atMs, text + whole[i + 1].text));
          i++;
        } else {
          out.add(e);
        }
        break;
      case 6: // a broken message before a good one
        out.add(Event(
            e.atMs - 500,
            'AGLoRa-point&ver=2.3&dev_batt=100&name=Tracker2'
            '&lat=59.9x&lon=&timestamp=not-a-time&index=#&crc=ok\r\n'));
        out.add(e);
        break;
      case 8: // cut off message, then the full one
        out.add(Event(e.atMs - 300, text.substring(0, 45)));
        out.add(e);
        break;
      case 10: // garbage without the prefix
        out.add(Event(e.atMs - 300, '~~noise@@##'));
        out.add(e);
        break;
      case 12: // split inside the timestamp
        final cut = text.indexOf('timestamp=') + 18;
        out.add(Event(e.atMs, text.substring(0, cut)));
        out.add(Event(e.atMs + 100, text.substring(cut)));
        break;
      default:
        out.add(e);
    }
  }
  return out;
}

void writeScenario(
    String dir, String id, String description, Track track, List<Event> events,
    {String connected = 'Tracker1'}) {
  int index = 0;
  int previousMs = 0;
  final out = StringBuffer()
    ..writeln('# AGLoRa demo scenario "$id": $description')
    ..writeln('# made by tool/make_demo_scenarios.dart, do not edit by hand')
    ..writeln('# line: <delay ms since the previous line> <text sent as is>')
    ..writeln('connected $connected')
    ..writeln('start ${_timestamp(track.start)}');
  for (final e in events) {
    // memory indexes go in the order the tracker received the points
    final text =
        e.text.replaceAllMapped('&index=#', (_) => '&index=${index++}');
    final delay = e.atMs - previousMs;
    previousMs = e.atMs;
    out.writeln('${delay < 0 ? 0 : delay} ${escapeLineBreaks(text)}');
  }
  File('$dir/$id.txt').writeAsStringSync(out.toString());
  print('$id: ${events.length} lines, ${previousMs ~/ 1000} s');
}

void main(List<String> args) {
  if (args.length != 2) {
    print('usage: dart run tool/make_demo_scenarios.dart <nmea.txt> <out dir>');
    exit(64);
  }
  final track = Track(readNmea(args[0]));
  final fullS = track.durationS;
  Directory(args[1]).createSync(recursive: true);

  final tracker1 = TrackerPlan('Tracker1', own: true);
  final tracker2 =
      TrackerPlan('Tracker2', phaseS: fullS ~/ 2, offsetS: 7, dLat: 0.002);

  writeScenario(args[1], 'normal', 'Tracker1 (connected) and Tracker2 move',
      track, plannedEvents(track, [tracker1, tracker2], fullS));

  writeScenario(
      args[1],
      'no_own_points',
      'only Tracker2 points arrive, as before the A2 firmware fix',
      track,
      plannedEvents(track, [tracker2], fullS));

  writeScenario(
      args[1],
      'link_loss',
      'Tracker2 sends for 2 minutes, then goes silent',
      track,
      plannedEvents(
          track,
          [
            tracker1,
            TrackerPlan('Tracker2',
                toS: 120, phaseS: fullS ~/ 2, offsetS: 7, dLat: 0.002),
          ],
          fullS));

  writeScenario(args[1], 'ragged', 'pieces, glued and broken messages', track,
      raggedEvents(plannedEvents(track, [tracker1, tracker2], 180)));

  writeScenario(
      args[1],
      'many',
      'five trackers at once',
      track,
      plannedEvents(
          track,
          [
            tracker1,
            tracker2,
            TrackerPlan('Tracker3',
                phaseS: fullS ~/ 4, offsetS: 3, dLon: -0.003),
            TrackerPlan('Tracker4',
                phaseS: fullS * 3 ~/ 4, offsetS: 10, dLat: -0.002),
            TrackerPlan('Tracker5',
                phaseS: fullS ~/ 3, offsetS: 12, dLat: 0.001, dLon: 0.003),
          ],
          fullS));

  // the search of a fallen UAV: the phone is on a person's tracker GROUND1,
  // UAV1 comes on air after 40 s, UAV2 goes silent after 90 s, GROUND2 is
  // another person, Tracker9 has an old-style name
  writeScenario(
      args[1],
      'search',
      'UAV search: UAV1 comes on air, UAV2 is lost, two people',
      track,
      plannedEvents(
          track,
          [
            TrackerPlan('GROUND1', own: true),
            TrackerPlan('UAV1',
                fromS: 40, phaseS: fullS ~/ 2, offsetS: 7, dLat: 0.004),
            TrackerPlan('UAV2',
                toS: 90, phaseS: fullS ~/ 4, offsetS: 3, dLon: -0.004),
            TrackerPlan('GROUND2',
                phaseS: fullS * 3 ~/ 4, offsetS: 10, dLat: -0.002),
            TrackerPlan('Tracker9',
                phaseS: fullS ~/ 3, offsetS: 12, dLat: 0.001, dLon: 0.003),
          ],
          fullS),
      connected: 'GROUND1');
}
