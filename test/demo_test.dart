import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/tracker_list.dart';
import 'package:tsp_tracker/demo/demo_data_source.dart';
import 'package:tsp_tracker/demo/demo_runner.dart';
import 'package:tsp_tracker/demo/demo_scenario.dart';

import 'helpers.dart';

DemoScenario loadScenario(String id) =>
    parseDemoScenario(File(demoScenarioAsset(id)).readAsStringSync());

/// all chunks of a scenario through the real parser, without waiting
Set<String> playInstantly(String id) {
  final scenario = loadScenario(id);
  final chunks = shiftScenarioTimes(scenario, DateTime.now());
  feed(memoryMessage(scenario.connectedTracker));
  for (final chunk in chunks) {
    feed(chunk.text);
  }
  return app.store.latestPoints.map((t) => t.identifier).toSet();
}

void main() {
  setUp(resetApp);

  test('scenario file format', () {
    final s = parseDemoScenario('# comment\n'
        'connected Tracker7\n'
        'start 2009-11-27T21:40:09Z\n'
        '300 AGLoRa-point&a=1\\r\\n\r\n'
        '200 piece with spaces\n');
    expect(s.connectedTracker, 'Tracker7');
    expect(s.start, DateTime.utc(2009, 11, 27, 21, 40, 9));
    expect(s.chunks.map((c) => c.atMs), [300, 500]);
    // \r\n in the file is the firmware's line break
    expect(s.chunks.first.text, 'AGLoRa-point&a=1\r\n');
    expect(s.chunks.last.text, 'piece with spaces');
  });

  test('times move to now, chunk lengths stay', () {
    final scenario = loadScenario('ragged');
    final start = DateTime.now();
    final shifted = shiftScenarioTimes(scenario, start, speed: 10);

    expect(shifted.map((c) => c.text.length),
        scenario.chunks.map((c) => c.text.length));
    final times = RegExp(r'timestamp=(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)')
        .allMatches(shifted.map((c) => c.text).join())
        .map((m) => DateTime.parse(m.group(1)!))
        .toList();
    expect(times, isNotEmpty);
    for (final t in times) {
      // the ragged scenario lasts 180 s, at ×10 it is 18 s
      expect(t.difference(start).inSeconds.abs(), lessThan(30));
    }
  });

  test('every scenario file is listed and parses', () {
    for (final id in demoScenarios.keys) {
      final s = loadScenario(id);
      expect(s.connectedTracker, id == 'search' ? 'GROUND1' : 'Tracker1',
          reason: id);
      expect(s.chunks, isNotEmpty, reason: id);
    }
  });

  test('1 normal: both trackers, own one blue-ready', () {
    expect(playInstantly('normal'), {'Tracker1', 'Tracker2'});
    expect(app.store.connectedTracker, 'Tracker1');
  });

  test('2 no own points: the connected tracker never shows up (A2 before)', () {
    expect(playInstantly('no_own_points'), {'Tracker2'});
  });

  test('3 link loss: Tracker2 stops after 2 minutes', () {
    playInstantly('link_loss');
    final t1 = app.store.pointsOf('Tracker1').first.time;
    final t2 = app.store.pointsOf('Tracker2').first.time;
    expect(t1.difference(t2).inMinutes, greaterThanOrEqualTo(5));
  });

  test('4 ragged: every good point is read, the broken one is not', () {
    final scenario = loadScenario('ragged');
    // complete messages as the joined stream has them: a cut-off one runs
    // into the next prefix and does not count
    final messages = RegExp(r'AGLoRa-point(?:(?!AGLoRa-)[^\n])*\n')
        .allMatches(scenario.chunks.map((c) => c.text).join())
        .map((m) => m.group(0)!)
        .toList();
    final good =
        messages.where((m) => RegExp(r'&lat=\d+\.\d{6}&').hasMatch(m)).length;
    expect(messages.length - good, 1, reason: 'one broken message');

    playInstantly('ragged');
    expect(app.store.pointCount, good);
    expect(app.store.latestPoints, hasLength(2));
  });

  test('5 many trackers', () {
    expect(playInstantly('many'), hasLength(5));
  });

  test('6 search: roles, the order, one alert per new UAV', () async {
    final alerts = <String>[];
    app.store.firstSignals.listen((s) => alerts.add(s.point.identifier));
    final names = playInstantly('search');
    await flush();
    expect(names, {'GROUND1', 'UAV1', 'UAV2', 'GROUND2', 'Tracker9'});
    expect(app.store.connectedTracker, 'GROUND1');

    // the own tracker on top, then UAVs in the order of appearance (UAV2
    // was on air first), then people
    final keys = buildTrackerList(app.store, DateTime.now().toUtc())
        .shown
        .map((e) => e.key)
        .toList();
    expect(keys.first, 'GROUND1');
    expect(keys.indexOf('UAV2'), lessThan(keys.indexOf('UAV1')));
    expect(keys.indexOf('UAV1'), lessThan(keys.indexOf('GROUND2')));
    expect(keys.last, 'Tracker9');
    expect(alerts, ['UAV2', 'UAV1'], reason: 'once each, in order of air');
  });

  test('the player answers all/crc/id/clear like the firmware', () async {
    final scenario = parseDemoScenario('connected Tracker1\n'
        'start 2026-10-28T12:00:00Z\n'
        '0 ${escapeLineBreaks(pointMessage('Tracker2', 53.9, 27.5, DateTime.utc(2026, 10, 28, 12), index: 0))}\n'
        '0 ${escapeLineBreaks(pointMessage('Tracker1', 53.8, 27.4, DateTime.utc(2026, 10, 28, 12)))}\n');
    final source = DemoDataSource(scenario, speed: 1);
    final received = StringBuffer();
    final sub = source.chunks
        .listen((chunk) => received.write(String.fromCharCodes(chunk)));

    source.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(source.isFinished, isTrue);
    received.clear();

    await source.send('all');
    await flush();
    expect(received.toString(), startsWith('AGLoRa-memory'));
    expect(received.toString(), contains('dev_name=Tracker1'));
    expect(received.toString(), contains('name=Tracker2'));
    // own points are not kept in the tracker memory
    expect(received.toString(), isNot(contains('&name=Tracker1')));

    received.clear();
    await source.send('id0');
    await flush();
    expect(received.toString(), contains('&index=0&'));

    received.clear();
    await source.send('clear');
    await source.send('all');
    await flush();
    expect(received.toString(), isNot(contains('AGLoRa-point')));

    await sub.cancel();
    source.dispose();
  });

  test('connecting a demo source requests the history', () async {
    final scenario = loadScenario('normal');
    final source = DemoDataSource(scenario, speed: 10);
    app.link.attach(source);
    source.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(app.store.connectedTracker, 'Tracker1');
    app.link.detach();
    expect(app.store.connectedTracker, isNull, reason: 'the link is gone');
  });
}
