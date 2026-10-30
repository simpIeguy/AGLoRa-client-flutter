import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/direction.dart';
import 'package:tsp_tracker/data/sensor_lamps.dart';
import 'package:tsp_tracker/data/tracker_list.dart';
import 'package:tsp_tracker/data/tracker_status.dart';
import 'package:tsp_tracker/data/tracker_store.dart';
import 'package:tsp_tracker/data/wait_names.dart';
import 'package:tsp_tracker/protocol/tracker_name.dart';
import 'package:tsp_tracker/protocol/tracker_point.dart';
import 'package:tsp_tracker/ui/names.dart';
import 'package:tsp_tracker/ui/strings.dart';

final DateTime now = DateTime.utc(2026, 10, 28, 12);

TrackerPoint at(String name, Duration age, {double lat = 53.9}) => TrackerPoint(
    identifier: name, latitude: lat, longitude: 27.5, time: now.subtract(age));

List<String> order(TrackerStore store) =>
    buildTrackerList(store, now).shown.map((e) => e.key).toList();

void main() {
  group('names and roles (1.1)', () {
    test('the role from the start of the name, any letter case', () {
      for (final raw in ['UAV1', 'uav1', 'Uav1', 'UAV 1', 'uav-1', 'UAV_1']) {
        final n = parseTrackerName(raw);
        expect(n.role, TrackerRole.uav, reason: raw);
        expect(n.number, 1, reason: raw);
        expect(n.key, 'UAV1', reason: raw);
      }
      expect(parseTrackerName('ground2').key, 'GROUND2');
      expect(parseTrackerName('GROUND 2').role, TrackerRole.ground);
    });

    test('numbers above 9, tails and garbage', () {
      expect(parseTrackerName('UAV12').number, 12);
      expect(parseTrackerName('UAV3x7').number, 3, reason: 'tail is ignored');
      expect(parseTrackerName('  uav5  ').key, 'UAV5');
      expect(parseTrackerName('UAV').number, isNull);
      expect(parseTrackerName('UAV').isKnown, isFalse);
      expect(parseTrackerName('Tracker1').role, TrackerRole.other);
      expect(parseTrackerName('Tracker1').key, 'Tracker1');
      expect(parseTrackerName('').role, TrackerRole.other);
      expect(parseTrackerName('#!*').isKnown, isFalse);
    });

    test('shown as "БЛА 1", "Человек 2", others as they are', () {
      expect(displayName(parseTrackerName('uav1')), 'БЛА 1');
      expect(displayName(parseTrackerName('GROUND2')), 'Человек 2');
      expect(displayName(parseTrackerName('Tracker1')), 'Tracker1');
      expect(displayName(parseTrackerName('UAV1'), alias: 'Орлан'), 'Орлан');
    });

    test('"uav1" and "UAV 1" are one tracker', () {
      final store = TrackerStore();
      store.addPoint(at('uav1', const Duration(minutes: 1)));
      store.addPoint(at('UAV 1', Duration.zero, lat: 54));
      expect(store.latestPoints, hasLength(1));
      expect(store.pointsOf('UAV1'), hasLength(2));
    });
  });

  group('the order of the list (2.1)', () {
    test(
        'UAVs first, lost ones among them, then waited, people, others;'
        ' inside a group the order of appearance', () {
      final store = TrackerStore()
        ..addPoint(at('Tracker9', Duration.zero))
        ..addPoint(at('GROUND2', const Duration(minutes: 10)))
        ..addPoint(at('GROUND1', const Duration(seconds: 5)))
        ..addPoint(at('UAV2', const Duration(minutes: 20)))
        ..addPoint(at('UAV1', const Duration(minutes: 2)))
        ..addPoint(at('UAV4', const Duration(seconds: 10)))
        ..addWaiting(parseTrackerName('UAV3'));
      expect(order(store), [
        'UAV1', 'UAV4', // a link, as they appeared (UAV4 is fresher)
        'UAV2', // lost, still among the UAVs
        'UAV3', // waited
        'GROUND1', 'GROUND2', // people
        'Tracker9',
      ]);
    });

    test('a new point does not move the card', () {
      final store = TrackerStore()
        ..addPoint(at('UAV1', const Duration(seconds: 30)))
        ..addPoint(at('UAV2', const Duration(seconds: 20)))
        ..addPoint(at('UAV3', const Duration(seconds: 10)));
      expect(order(store), ['UAV1', 'UAV2', 'UAV3']);
      store.addPoint(at('UAV1', Duration.zero, lat: 54));
      expect(order(store), ['UAV1', 'UAV2', 'UAV3']);
    });

    test('dragged cards keep their places, a new one comes last', () {
      final store = TrackerStore()
        ..addPoint(at('UAV1', const Duration(seconds: 30)))
        ..addPoint(at('UAV2', const Duration(seconds: 20)))
        ..addPoint(at('GROUND1', const Duration(seconds: 15)))
        ..addPoint(at('GROUND2', const Duration(seconds: 10)));
      store.setOrder(['UAV2', 'UAV1']);
      store.setOrder(['GROUND2', 'GROUND1']);
      expect(order(store), ['UAV2', 'UAV1', 'GROUND2', 'GROUND1']);

      store.addPoint(at('UAV3', Duration.zero));
      expect(order(store), ['UAV2', 'UAV1', 'UAV3', 'GROUND2', 'GROUND1']);
    });

    test('the groups stay: a dragged order never lifts people over UAVs', () {
      final store = TrackerStore()
        ..addPoint(at('UAV1', const Duration(seconds: 30)))
        ..addPoint(at('GROUND1', const Duration(seconds: 15)));
      store.setOrder(['GROUND1', 'UAV1']);
      expect(order(store), ['UAV1', 'GROUND1']);
    });

    test('the order survives a restart and an old save without it', () {
      final before = TrackerStore()
        ..addPoint(at('UAV1', const Duration(seconds: 30)))
        ..addPoint(at('UAV2', const Duration(seconds: 20)))
        ..setOrder(['UAV2', 'UAV1']);
      final after = TrackerStore();
      expect(after.loadState(before.saveState()), isTrue);
      expect(order(after), ['UAV2', 'UAV1']);

      final old = before.saveState()..remove('order');
      expect(TrackerStore().loadState(old), isTrue);
    });

    test('the connected tracker counts as having a link', () {
      final store = TrackerStore()
        ..addPoint(at('GROUND3', const Duration(minutes: 10)))
        ..addPoint(at('GROUND1', const Duration(hours: 1)))
        ..setConnectedTracker('ground1');
      // an hour old, but connected: on top of everything
      expect(buildTrackerList(store, now).shown.first.status,
          TrackerStatus.connected);
      expect(order(store), ['GROUND1', 'GROUND3']);
    });
  });

  group('who to show and the archive (2.4)', () {
    test('people can be hidden, UAVs and the connected tracker can not', () {
      final store = TrackerStore()
        ..addPoint(at('UAV1', Duration.zero))
        ..addPoint(at('GROUND1', Duration.zero))
        ..addPoint(at('GROUND2', Duration.zero))
        ..setConnectedTracker('GROUND1')
        ..setHidden('UAV1', true)
        ..setHidden('GROUND1', true)
        ..setHidden('GROUND2', true);
      final list = buildTrackerList(store, now);
      expect(list.shown.map((e) => e.key), ['GROUND1', 'UAV1']);
      expect(list.hiddenCount, 1);
      expect(buildTrackerList(store, now, includeHidden: true).shown,
          hasLength(3));
    });

    test('7 days without data: to the archive; waited ones never', () {
      final store = TrackerStore()
        ..addPoint(at('UAV1', const Duration(days: 8)))
        ..addPoint(at('GROUND1', const Duration(days: 6)))
        ..addWaiting(parseTrackerName('UAV2'),
            since: now.subtract(const Duration(days: 30)));
      final list = buildTrackerList(store, now);
      expect(list.archived.map((e) => e.key), ['UAV1']);
      expect(list.shown.map((e) => e.key), ['UAV2', 'GROUND1']);
      expect(trackerArchiveAfter, const Duration(days: 7));
    });
  });

  group('waiting and the first signal (4)', () {
    test('quick picks: the taken ones in a row, then the first free', () {
      final taken = {'UAV1', 'UAV2', 'UAV3', 'GROUND1', 'GROUND2'};
      final quick = quickWaitNames(taken.contains);
      expect(quick.map((q) => q.key), [
        'UAV1', 'UAV2', 'UAV3', 'UAV4', 'UAV5', //
        'GROUND1', 'GROUND2', 'GROUND3',
      ]);
      expect(quick.where((q) => q.taken).length, 5);
      // a gap is a free name too
      expect(quickWaitNames({'UAV2'}.contains).map((q) => q.key),
          ['UAV1', 'UAV2', 'UAV3', 'GROUND1']);
    });

    test('"Ждать 3 трекера": the Russian plural', () {
      expect(S.waitForCount(2), 'Ждать 2 трекера');
      expect(S.waitForCount(5), 'Ждать 5 трекеров');
      expect(S.waitForCount(11), 'Ждать 11 трекеров');
      expect(S.waitForCount(21), 'Ждать 21 трекер');
    });

    test('waited silently: no alert, not even as a new UAV', () async {
      final store = TrackerStore(now: () => now)
        ..addWaiting(parseTrackerName('UAV4'), notify: false);
      final signals = <FirstSignal>[];
      store.firstSignals.listen(signals.add);
      store.addPoint(at('UAV4', Duration.zero));
      await Future<void>.delayed(Duration.zero);
      expect(signals, isEmpty);
      expect(store.waiting, isEmpty, reason: 'it is in the list now');
    });

    test('a waited tracker alerts once, then is an ordinary one', () async {
      final store = TrackerStore(now: () => now);
      final signals = <FirstSignal>[];
      store.firstSignals.listen(signals.add);
      expect(
          store.addWaiting(parseTrackerName('ground3'), alias: 'Пётр'), isTrue);
      expect(store.addWaiting(parseTrackerName('GROUND 3')), isFalse,
          reason: 'already waited');

      store.addPoint(at('GROUND3', Duration.zero));
      store.addPoint(at('GROUND3', const Duration(seconds: -30)));
      await Future<void>.delayed(Duration.zero);

      expect(signals, hasLength(1));
      expect(signals.single.wasWaited, isTrue);
      expect(store.waiting, isEmpty);
      expect(store.aliasOf('ground3'), 'Пётр');
    });

    test('old points from the history do not alert, a fresh one does',
        () async {
      final store = TrackerStore(now: () => now);
      final signals = <FirstSignal>[];
      store.firstSignals.listen(signals.add);
      store.addWaiting(parseTrackerName('UAV7'));

      store.addPoint(at('UAV7', const Duration(days: 3)));
      store.addPoint(at('UAV8', const Duration(hours: 1)));
      await Future<void>.delayed(Duration.zero);
      expect(signals, isEmpty);
      expect(store.waiting, isEmpty, reason: 'it is in the list now');

      store.addPoint(at('UAV7', const Duration(seconds: 20)));
      store.addPoint(at('UAV7', const Duration(seconds: 5)));
      await Future<void>.delayed(Duration.zero);
      expect(signals, hasLength(1));
      expect(signals.single.wasWaited, isTrue);
    });

    test('one fix from "UAV 1" and "UAV1" is stored once', () {
      final store = TrackerStore();
      store.addPoint(at('UAV 1', Duration.zero));
      expect(store.addPoint(at('UAV1', Duration.zero)), isFalse);
    });

    test('aliases and removing a stub', () {
      final store = TrackerStore()
        ..addWaiting(parseTrackerName('GROUND5'), alias: '  Иван ');
      expect(store.aliasOf('ground 5'), 'Иван');
      store.setAlias('GROUND5', 'Пётр');
      expect(store.aliasOf('GROUND5'), 'Пётр');
      store.setAlias('GROUND5', ' ');
      expect(store.aliasOf('GROUND5'), isNull);
      store.removeWaiting('ground5');
      expect(store.waiting, isEmpty);
      expect(store.isKnown('GROUND5'), isFalse);
    });

    test('one tracker removed: the rest stay, it can come back', () async {
      final store = TrackerStore(now: () => now)
        ..addPoint(at('UAV1', Duration.zero))
        ..addPoint(at('UAV2', Duration.zero))
        ..setAlias('UAV1', 'Первый')
        ..heardWithoutFix('UAV1');
      final signals = <FirstSignal>[];
      store.firstSignals.listen(signals.add);

      store.removeTracker('uav 1');
      expect(store.pointsOf('UAV1'), isEmpty);
      expect(store.aliasOf('UAV1'), isNull);
      expect(store.isKnown('UAV1'), isFalse);
      expect(store.pointsOf('UAV2'), hasLength(1));

      // still on air: a new tracker again, with its "came on air"
      store.addPoint(at('UAV1', const Duration(seconds: -5)));
      await Future<void>.delayed(Duration.zero);
      expect(signals.map((s) => s.point.identifier), ['UAV1']);
    });

    test('any new UAV alerts by default; it can be switched off', () async {
      final store = TrackerStore(now: () => now);
      final signals = <FirstSignal>[];
      store.firstSignals.listen(signals.add);

      store.addPoint(at('UAV1', Duration.zero));
      store.addPoint(at('GROUND1', Duration.zero)); // people do not
      store.addPoint(at('Tracker1', Duration.zero));
      store.alertNewUavs = false;
      store.addPoint(at('UAV2', Duration.zero));
      await Future<void>.delayed(Duration.zero);

      expect(signals.map((s) => s.point.identifier), ['UAV1']);
      expect(signals.single.wasWaited, isFalse);
    });
  });

  group('on air without a GPS fix', () {
    test('heard only without a fix: in the list, no coordinates', () {
      final store = TrackerStore(now: () => now)..heardWithoutFix('uav 5');
      final entry = buildTrackerList(store, now).shown.single;
      expect(entry.key, 'UAV5');
      expect(entry.latest, isNull);
      expect(entry.searchingSatellites, isTrue);
      expect(entry.status, TrackerStatus.active);
      expect(store.isKnown('UAV5'), isTrue);
    });

    test('a fix, then none: the last good point, the link is alive', () {
      var clock = now;
      final store = TrackerStore(now: () => clock)
        ..addPoint(at('UAV1', const Duration(minutes: 10), lat: 54));
      expect(
          buildTrackerList(store, now).shown.single.status, TrackerStatus.lost);

      store.heardWithoutFix('UAV1');
      var entry = buildTrackerList(store, now).shown.single;
      expect(entry.status, TrackerStatus.active);
      expect(entry.latest!.latitude, 54, reason: 'coordinates of the fix');
      expect(entry.searchingSatellites, isTrue);
      expect(entry.lastHeard, now);

      // satellites are back
      clock = now.add(const Duration(seconds: 30));
      store.addPoint(at('UAV1', const Duration(seconds: -30), lat: 55));
      entry = buildTrackerList(store, clock).shown.single;
      expect(entry.searchingSatellites, isFalse);
      expect(entry.latest!.latitude, 55);
    });

    test('a waited tracker leaves the stubs, alerts on its first fix',
        () async {
      final store = TrackerStore(now: () => now);
      final signals = <FirstSignal>[];
      store.firstSignals.listen(signals.add);
      store.addWaiting(parseTrackerName('UAV3'));

      store.heardWithoutFix('UAV3');
      await Future<void>.delayed(Duration.zero);
      expect(store.waiting, isEmpty);
      expect(signals, isEmpty, reason: 'nowhere to go yet');

      store.addPoint(at('UAV3', Duration.zero));
      await Future<void>.delayed(Duration.zero);
      expect(signals.single.wasWaited, isTrue);
    });

    test('a reset forgets it', () {
      final store = TrackerStore()..heardWithoutFix('UAV1');
      store.reset();
      expect(store.trackersWithoutPoints, isEmpty);
      expect(store.lastHeard('UAV1'), isNull);
    });
  });

  group('arrow problems and lamps (6, 7)', () {
    Direction direction({
      double? phoneLat = 53.9,
      bool hasReading = true,
      double? accuracy = 15,
    }) =>
        directionTo(
          latitude: 54,
          longitude: 27.5,
          phoneLatitude: phoneLat,
          phoneLongitude: phoneLat == null ? null : 27.5,
          hasCompassReading: hasReading,
          compassAccuracy: accuracy,
        );

    test('no wrong values: a reason instead', () {
      expect(direction().problem, DirectionProblem.none);
      expect(direction().distance, closeTo(11132, 20));
      expect(
          direction(phoneLat: null).problem, DirectionProblem.noPhonePosition);
      expect(direction(phoneLat: null).distance, isNull);
      expect(direction(hasReading: false).problem, DirectionProblem.noCompass);
      expect(
          direction(accuracy: 45).problem, DirectionProblem.compassUnreliable);
    });

    test('GPS lamp', () {
      final t = DateTime(2026, 10, 28, 12);
      expect(gpsLamp(fixTime: t, accuracy: 6, now: t), LampLevel.good);
      expect(gpsLamp(fixTime: t, accuracy: 25, now: t), LampLevel.fair);
      expect(
          gpsLamp(
              fixTime: t, accuracy: 6, now: t.add(const Duration(seconds: 30))),
          LampLevel.fair,
          reason: 'a stale fix');
      expect(gpsLamp(fixTime: null, accuracy: null, now: t), LampLevel.bad);
    });

    test('compass lamp', () {
      LampLevel lamp(double? a, {bool has = true}) =>
          compassLamp(hasReading: has, accuracy: a);
      expect(lamp(15), LampLevel.good);
      expect(lamp(30), LampLevel.fair);
      expect(lamp(45), LampLevel.bad);
      expect(lamp(null), LampLevel.fair);
      expect(lamp(15, has: false), LampLevel.bad);
    });
  });
}
