import 'package:aglora_client/aglora/aglora.dart';
import 'package:aglora_client/aglora/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final now = DateTime.now().toUtc();

  setUp(resetApp);

  test('a whole message in one chunk', () {
    newDataReceiver(
        pointMessage('Tracker2', 53.902284, 27.561831, now, index: 0)
            .codeUnits);

    expect(agloraAppMemory.trackers, hasLength(1));
    final point = agloraAppMemory.trackers.single;
    expect(point.identifier, 'Tracker2');
    expect(point.latitude, closeTo(53.902284, 1e-6));
    expect(point.longitude, closeTo(27.561831, 1e-6));
    expect(point.sensor('alt'), '120.5');
    expect(point.sensor('battery'), '87');
    expect(point.sensor('gpsValid'), '1');
  });

  test('a message in 20-character BLE pieces keeps all its fields', () {
    feed(pointMessage('Tracker2', 53.9, 27.5, now, index: 0));
    expect(agloraAppMemory.memory, hasLength(1));
    final point = agloraAppMemory.memory.single;
    expect(point.identifier, 'Tracker2');
    // the seconds of the time come in a later piece than the hours
    expect(point.time, DateTime.parse(formatTime(now)));
    expect(point.sensor('alt'), '120.5');
    expect(point.sensor('sat'), '9');
    expect(point.sensor('battery'), '87');
  });

  test('an unfinished message is not parsed yet', () {
    final text = pointMessage('Tracker2', 53.9, 27.5, now, index: 0);
    feed(text.substring(0, text.indexOf('&gpsValid')));
    expect(agloraAppMemory.memory, isEmpty);
  });

  test('pieces with odd sizes and a cut inside the timestamp', () {
    final text = pointMessage('Tracker2', 53.9, 27.5, now, index: 0);
    final cut = text.indexOf('timestamp=') + 15;
    newDataReceiver(text.substring(0, 7).codeUnits);
    newDataReceiver(text.substring(7, cut).codeUnits);
    expect(agloraAppMemory.trackers, isEmpty);
    newDataReceiver(text.substring(cut).codeUnits);
    expect(agloraAppMemory.trackers, hasLength(1));
    expect(
        agloraAppMemory.trackers.single.time, DateTime.parse(formatTime(now)));
  });

  test('two messages glued into one chunk', () {
    newDataReceiver((pointMessage('Tracker2', 53.9, 27.5, now, index: 0) +
            pointMessage('Tracker3', 54.0, 27.6, now, index: 1))
        .codeUnits);
    expect(agloraAppMemory.trackers.map((t) => t.identifier),
        containsAll(['Tracker2', 'Tracker3']));
  });

  test('a broken message is skipped, the next one is read', () {
    feed('AGLoRa-point&ver=2.3&name=Tracker2&lat=53.9x&lon='
        '&timestamp=not-a-time|');
    expect(agloraAppMemory.trackers, isEmpty);

    feed(pointMessage('Tracker2', 53.9, 27.5, now, index: 1));
    expect(agloraAppMemory.trackers, hasLength(1));
  });

  test('a cut-off message followed by a new one', () {
    final full = pointMessage('Tracker2', 53.9, 27.5, now, index: 0);
    feed(full.substring(0, 45));
    feed(full);
    expect(agloraAppMemory.memory, hasLength(1));
    expect(agloraAppMemory.trackers.single.latitude, closeTo(53.9, 1e-6));
  });

  test('garbage without the prefix does not break parsing', () {
    feed('~~noise@@##');
    feed(pointMessage('Tracker2', 53.9, 27.5, now, index: 0));
    expect(agloraAppMemory.trackers, hasLength(1));
  });

  test('a long stream of garbage does not grow the buffer forever', () {
    for (int i = 0; i < 100; i++) {
      newDataReceiver('garbage-$i-no-terminator '.codeUnits);
    }
    feed(pointMessage('Tracker2', 53.9, 27.5, now, index: 0));
    expect(agloraAppMemory.trackers, hasLength(1));
  });

  test('(0, 0) means no GPS fix and is skipped', () {
    feed(pointMessage('Tracker2', 0, 0, now, index: 0));
    expect(agloraAppMemory.trackers, isEmpty);
  });

  test('the memory message tells which tracker the phone is on', () {
    feed(memoryMessage('Tracker1'));
    expect(agloraAppMemory.connectedTracker, 'Tracker1');
  });

  test('own point without index and crc (A2 firmware fix) is read', () {
    feed(memoryMessage('Tracker1'));
    feed(pointMessage('Tracker1', 53.9, 27.5, now));
    expect(agloraAppMemory.trackers.single.identifier, 'Tracker1');
  });

  test('a newer point updates the right tracker only', () {
    final earlier = now.subtract(Duration(seconds: 30));
    feed(pointMessage('Tracker1', 53.0, 27.0, earlier));
    feed(pointMessage('Tracker2', 54.0, 28.0, earlier, index: 0));
    feed(pointMessage('Tracker1', 53.5, 27.5, now));

    final byName = {
      for (final t in agloraAppMemory.trackers) t.identifier: t,
    };
    expect(byName['Tracker1']!.latitude, closeTo(53.5, 1e-6));
    expect(byName['Tracker2']!.latitude, closeTo(54.0, 1e-6));
  });

  test('the same point twice is stored once', () {
    final text = pointMessage('Tracker2', 53.9, 27.5, now, index: 0);
    feed(text);
    feed(text);
    expect(agloraAppMemory.memory, hasLength(1));
  });
}

String formatTime(DateTime t) => '${t.toIso8601String().substring(0, 19)}Z';
