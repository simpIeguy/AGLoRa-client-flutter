import 'dart:async';
import 'dart:io';

import 'package:tsp_tracker/aglora/aglora.dart';
import 'package:tsp_tracker/aglora/data_source.dart';
import 'package:tsp_tracker/aglora/memory.dart';
import 'package:tsp_tracker/demo/demo_data_source.dart';
import 'package:tsp_tracker/demo/demo_scenario.dart';
import 'package:tsp_tracker/demo/demo_screen.dart';
import 'package:flutter_test/flutter_test.dart';

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
  return agloraAppMemory.trackers.map((t) => t.identifier).toSet();
}

void main() {
  setUp(resetApp);

  test('scenario file format', () {
    final s = parseDemoScenario('# comment\n'
        'connected Tracker7\n'
        'start 2009-11-27T21:40:09Z\n'
        '300 AGLoRa-point&a=1|\r\n'
        '200 piece with spaces\n');
    expect(s.connectedTracker, 'Tracker7');
    expect(s.start, DateTime.utc(2009, 11, 27, 21, 40, 9));
    expect(s.chunks.map((c) => c.atMs), [300, 500]);
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
      expect(s.connectedTracker, 'Tracker1', reason: id);
      expect(s.chunks, isNotEmpty, reason: id);
    }
  });

  test('1 normal: both trackers, own one blue-ready', () {
    expect(playInstantly('normal'), {'Tracker1', 'Tracker2'});
    expect(agloraAppMemory.connectedTracker, 'Tracker1');
  });

  test('2 no own points: the connected tracker never shows up (A2 before)', () {
    expect(playInstantly('no_own_points'), {'Tracker2'});
  });

  test('3 link loss: Tracker2 stops after 2 minutes', () {
    playInstantly('link_loss');
    final t1 = agloraAppMemory.pointsOf('Tracker1').first.time;
    final t2 = agloraAppMemory.pointsOf('Tracker2').first.time;
    expect(t1.difference(t2).inMinutes, greaterThanOrEqualTo(5));
  });

  test('4 ragged: every good point is read, the broken one is not', () {
    final scenario = loadScenario('ragged');
    // complete messages as the joined stream has them: a cut-off one runs
    // into the next prefix and does not count
    final messages = RegExp(r'AGLoRa-point(?:(?!AGLoRa-)[^|])*\|')
        .allMatches(scenario.chunks.map((c) => c.text).join())
        .map((m) => m.group(0)!)
        .toList();
    final good =
        messages.where((m) => RegExp(r'&lat=\d+\.\d{6}&').hasMatch(m)).length;
    expect(messages.length - good, 1, reason: 'one broken message');

    playInstantly('ragged');
    expect(agloraAppMemory.memory.length, good);
    expect(agloraAppMemory.trackers, hasLength(2));
  });

  test('5 many trackers', () {
    expect(playInstantly('many'), hasLength(5));
  });

  test('the player answers all/crc/id/clear like the firmware', () async {
    final scenario = parseDemoScenario('connected Tracker1\n'
        'start 2026-10-28T12:00:00Z\n'
        '0 ${pointMessage('Tracker2', 53.9, 27.5, DateTime.utc(2026, 10, 28, 12), index: 0)}\n'
        '0 ${pointMessage('Tracker1', 53.8, 27.4, DateTime.utc(2026, 10, 28, 12))}\n');
    final source = DemoDataSource(scenario, speed: 1);
    final received = StringBuffer();
    final sub = source.chunks
        .listen((chunk) => received.write(String.fromCharCodes(chunk)));

    source.start();
    await Future<void>.delayed(Duration(milliseconds: 50));
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
    attachDataSource(source);
    source.start();
    await Future<void>.delayed(Duration(milliseconds: 100));
    expect(agloraAppMemory.connectedTracker, 'Tracker1');
    detachDataSource();
    resetDataReceiver();
  });
}

/// broadcast streams deliver in microtasks: let them run
Future<void> flush() => Future<void>.delayed(Duration.zero);
