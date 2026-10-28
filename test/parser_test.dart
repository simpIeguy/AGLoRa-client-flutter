import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/protocol/message_buffer.dart';
import 'package:tsp_tracker/protocol/messages.dart';

import 'helpers.dart';

void main() {
  final now = DateTime.now().toUtc();

  setUp(resetApp);

  test('a whole message in one chunk', () {
    app.link.receive(
        pointMessage('Tracker2', 53.902284, 27.561831, now, index: 0)
            .codeUnits);

    expect(app.store.latestPoints, hasLength(1));
    final point = app.store.latestPoints.single;
    expect(point.identifier, 'Tracker2');
    expect(point.latitude, closeTo(53.902284, 1e-6));
    expect(point.longitude, closeTo(27.561831, 1e-6));
    expect(point.sensor('alt'), '120.5');
    expect(point.sensor('battery'), '87');
    expect(point.sensor('gpsValid'), '1');
  });

  test('a message in 20-character BLE pieces keeps all its fields', () {
    feed(pointMessage('Tracker2', 53.9, 27.5, now, index: 0));
    expect(app.store.pointCount, 1);
    final point = app.store.latestPoints.single;
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
    expect(app.store.pointCount, 0);
  });

  test('pieces with odd sizes and a cut inside the timestamp', () {
    final text = pointMessage('Tracker2', 53.9, 27.5, now, index: 0);
    final cut = text.indexOf('timestamp=') + 15;
    app.link.receive(text.substring(0, 7).codeUnits);
    app.link.receive(text.substring(7, cut).codeUnits);
    expect(app.store.latestPoints, isEmpty);
    app.link.receive(text.substring(cut).codeUnits);
    expect(app.store.latestPoints, hasLength(1));
    expect(app.store.latestPoints.single.time, DateTime.parse(formatTime(now)));
  });

  test('the prefix itself cut between two chunks', () {
    final text = pointMessage('Tracker2', 53.9, 27.5, now, index: 0);
    app.link.receive('noise AGLo'.codeUnits);
    app.link.receive(text.substring(4).codeUnits);
    expect(app.store.latestPoints, hasLength(1));
  });

  test('two messages glued into one chunk', () {
    app.link.receive((pointMessage('Tracker2', 53.9, 27.5, now, index: 0) +
            pointMessage('Tracker3', 54.0, 27.6, now, index: 1))
        .codeUnits);
    expect(app.store.latestPoints.map((t) => t.identifier),
        containsAll(['Tracker2', 'Tracker3']));
  });

  test('a broken message is skipped, the next one is read', () {
    feed('AGLoRa-point&ver=2.3&name=Tracker2&lat=53.9x&lon='
        '&timestamp=not-a-time|');
    expect(app.store.latestPoints, isEmpty);

    feed(pointMessage('Tracker2', 53.9, 27.5, now, index: 1));
    expect(app.store.latestPoints, hasLength(1));
  });

  test('a cut-off message followed by a new one', () {
    final full = pointMessage('Tracker2', 53.9, 27.5, now, index: 0);
    feed(full.substring(0, 45));
    feed(full);
    expect(app.store.pointCount, 1);
    expect(app.store.latestPoints.single.latitude, closeTo(53.9, 1e-6));
  });

  test('garbage without the prefix does not break parsing', () {
    feed('~~noise@@##');
    feed(pointMessage('Tracker2', 53.9, 27.5, now, index: 0));
    expect(app.store.latestPoints, hasLength(1));
  });

  test('a long stream of garbage does not grow the buffer forever', () {
    final buffer = MessageBuffer();
    for (int i = 0; i < 100; i++) {
      buffer.add('AGLoRa-garbage-$i-no-terminator '.codeUnits);
    }
    final messages = buffer
        .add(pointMessage('Tracker2', 53.9, 27.5, now, index: 0).codeUnits);
    expect(messages, hasLength(1));
  });

  test('(0, 0) means no GPS fix and is skipped', () {
    feed(pointMessage('Tracker2', 0, 0, now, index: 0));
    expect(app.store.latestPoints, isEmpty);
  });

  test('the memory message tells which tracker the phone is on', () {
    feed(memoryMessage('Tracker1'));
    expect(app.store.connectedTracker, 'Tracker1');
  });

  test('a memory message without a name keeps the connected tracker', () {
    feed(memoryMessage('Tracker1'));
    feed('AGLoRa-memory&ver=2.3&memsize=100&index=0&overwrite=0|');
    expect(app.store.connectedTracker, 'Tracker1');
  });

  test('own point without index and crc (A2 firmware fix) is read', () {
    feed(memoryMessage('Tracker1'));
    feed(pointMessage('Tracker1', 53.9, 27.5, now));
    expect(app.store.latestPoints.single.identifier, 'Tracker1');
  });

  test('a newer point updates the right tracker only', () {
    final earlier = now.subtract(const Duration(seconds: 30));
    feed(pointMessage('Tracker1', 53.0, 27.0, earlier));
    feed(pointMessage('Tracker2', 54.0, 28.0, earlier, index: 0));
    feed(pointMessage('Tracker1', 53.5, 27.5, now));

    final byName = {
      for (final t in app.store.latestPoints) t.identifier: t,
    };
    expect(byName['Tracker1']!.latitude, closeTo(53.5, 1e-6));
    expect(byName['Tracker2']!.latitude, closeTo(54.0, 1e-6));
  });

  test('the same point twice is stored once', () {
    final text = pointMessage('Tracker2', 53.9, 27.5, now, index: 0);
    feed(text);
    feed(text);
    expect(app.store.pointCount, 1);
  });

  test('message types', () {
    expect(parseMessage('memory&dev_name=UAV1'), isA<MemoryMessage>());
    expect(parseMessage('info&myId=7'), isA<InfoMessage>());
    expect(parseMessage('unknown&a=1'), isNull);
    final point = parseMessage(
        'point&name=UAV1&lat=53.9&lon=27.5&timestamp=2026-10-28T12:00:00Z'
        '&sat=9&weird=a=b');
    expect(point, isA<PointMessage>());
    final p = (point as PointMessage).point;
    expect(p.sensor('sat'), '9');
    expect(p.sensor('weird'), isNull, reason: 'a value with "=" is skipped');
  });
}

String formatTime(DateTime t) => '${t.toIso8601String().substring(0, 19)}Z';
