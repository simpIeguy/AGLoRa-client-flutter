import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/tracker_store.dart';
import 'package:tsp_tracker/protocol/tracker_name.dart';
import 'package:tsp_tracker/protocol/tracker_point.dart';
import 'package:tsp_tracker/services/app_settings.dart';
import 'package:tsp_tracker/services/app_storage.dart';
import 'package:tsp_tracker/ui/format.dart';
import 'package:tsp_tracker/ui/theme.dart';

final now = DateTime.utc(2026, 10, 29, 12);

TrackerPoint at(String name, Duration age, {double lat = 53.9}) => TrackerPoint(
        identifier: name,
        latitude: lat,
        longitude: 27.5,
        time: now.subtract(age),
        sensors: const [
          TrackerSensor(name: 'sat', value: '9'),
          TrackerSensor(name: 'alt', value: '142.3'),
        ]);

/// through JSON text, as on the phone
Object? throughText(Map<String, Object?> state) =>
    jsonDecode(jsonEncode(state));

void main() {
  group('the trackers between launches', () {
    test('everything worth keeping comes back', () {
      final before = TrackerStore(now: () => now)
        ..addPoint(at('UAV1', const Duration(minutes: 1)))
        ..addPoint(at('UAV1', Duration.zero, lat: 53.91))
        ..addPoint(at('GROUND2', Duration.zero))
        ..setAlias('GROUND2', 'Саша')
        ..addWaiting(parseTrackerName('UAV4'), since: now, notify: false)
        ..setHidden('GROUND2', true)
        ..heardWithoutFix('UAV7')
        ..setThresholds(fadingAfter: const Duration(minutes: 2))
        ..alertNewUavs = false
        ..setConnectedTracker('GROUND2');

      final after = TrackerStore(now: () => now);
      expect(after.loadState(throughText(before.saveState())), isTrue);

      final points = after.pointsOf('UAV1');
      expect(points.map((p) => p.latitude), [53.91, 53.9],
          reason: 'the newest first');
      expect(points.first.time, now);
      expect(points.first.sensor('alt'), '142.3');
      expect(after.aliasOf('ground 2'), 'Саша');
      expect(after.waiting.single.name.key, 'UAV4');
      expect(after.waiting.single.notify, isFalse);
      expect(after.isHidden('GROUND2'), isTrue);
      expect(after.trackersWithoutPoints, ['UAV7']);
      expect(after.fadingAfter, const Duration(minutes: 2));
      expect(after.alertNewUavs, isFalse);
      expect(after.connectedTracker, isNull,
          reason: 'the tracker is picked again after a launch');
    });

    test('kept trackers do not say "came on air" again', () async {
      final before = TrackerStore(now: () => now)
        ..addPoint(at('UAV1', const Duration(seconds: 30)));
      final after = TrackerStore(now: () => now)
        ..loadState(throughText(before.saveState()));
      final signals = <FirstSignal>[];
      after.firstSignals.listen(signals.add);
      after.addPoint(at('UAV1', Duration.zero, lat: 53.91));
      await Future<void>.delayed(Duration.zero);
      expect(signals, isEmpty);
    });

    test('at most 50 points of a tracker, also from a saved file', () {
      final state = TrackerStore(now: () => now).saveState()
        ..['points'] = {
          'UAV1': [
            for (int i = 0; i < 80; i++)
              {
                'id': 'UAV1',
                'lat': 53.9,
                'lon': 27.5,
                'time':
                    now.subtract(Duration(seconds: i)).millisecondsSinceEpoch,
                'got': now.millisecondsSinceEpoch,
                'sensors': <String, String>{},
              },
          ],
        };
      final store = TrackerStore(now: () => now)..loadState(throughText(state));
      expect(store.pointsOf('UAV1'),
          hasLength(TrackerStore.pointsPerTrackerLimit));
      expect(store.pointsOf('UAV1').first.time, now, reason: 'the newest kept');
    });

    test('damaged or foreign data: an empty start, not a crash', () {
      final good = TrackerStore(now: () => now)
        ..addPoint(at('UAV1', Duration.zero));
      for (final bad in <Object?>[
        null,
        'text',
        {'version': 99},
        {...good.saveState(), 'points': 'oops'},
        {...good.saveState(), 'lostAfter': 10, 'fadingAfter': 60},
      ]) {
        final store = TrackerStore(now: () => now)
          ..addPoint(at('GROUND1', Duration.zero));
        expect(store.loadState(bad), isFalse, reason: '$bad');
        expect(store.pointsOf('GROUND1'), hasLength(1),
            reason: 'nothing half-loaded over what there was');
      }
    });
  });

  test('the settings come back; what is not understood keeps the default', () {
    final before = AppSettings()
      ..theme = AppThemeChoice.night
      ..coordinates = CoordinateFormat.dms
      ..keepScreenOn = false
      ..setTrackShown('UAV1', false);
    final after = AppSettings()..loadState(throughText(before.saveState()));
    expect(after.theme, AppThemeChoice.night);
    expect(after.coordinates, CoordinateFormat.dms);
    expect(after.keepScreenOn, isFalse);
    expect(after.isTrackShown('UAV1'), isFalse);
    expect(after.isTrackShown('UAV2'), isTrue);

    final odd = AppSettings()
      ..loadState({'version': 1, 'theme': 'purple', 'keepScreenOn': 'yes'});
    expect(odd.theme, AppThemeChoice.auto);
    expect(odd.keepScreenOn, isTrue);
  });

  group('writing to the phone', () {
    test('a moment after the changes, once for a burst', () {
      fakeAsync((async) {
        final disk = _CountingStorage();
        final store = TrackerStore(now: () => now);
        final storage = AppStorage(store, AppSettings(), backend: disk)
          ..start();
        async.flushMicrotasks();

        for (int i = 0; i < 10; i++) {
          store.addPoint(at('UAV1', Duration(seconds: i)));
        }
        async.elapse(const Duration(seconds: 1));
        expect(disk.writes, 0);
        async.elapse(const Duration(seconds: 2));
        expect(disk.writes, 2, reason: 'the trackers and the settings');

        final next = TrackerStore(now: () => now);
        AppStorage(next, AppSettings(), backend: disk).start();
        async.flushMicrotasks();
        expect(next.pointsOf('UAV1'), hasLength(10));
        storage.dispose();
      });
    });

    test('the demo is not kept; the own trackers come back after it', () {
      fakeAsync((async) {
        final disk = MemoryStorage();
        final store = TrackerStore(now: () => now)
          ..addPoint(at('GROUND1', Duration.zero));
        final storage = AppStorage(store, AppSettings(), backend: disk)
          ..start();
        async.flushMicrotasks();

        storage.pause();
        async.flushMicrotasks();
        store
          ..reset()
          ..addPoint(at('UAV9', Duration.zero));
        async.elapse(const Duration(seconds: 5));

        store.reset();
        storage.resume();
        async.flushMicrotasks();
        expect(store.pointsOf('GROUND1'), hasLength(1));
        expect(store.pointsOf('UAV9'), isEmpty);
        storage.dispose();
      });
    });

    test('a damaged file: the app starts empty', () async {
      final disk = MemoryStorage()
        ..values[AppStorage.trackersKey] = '{not json'
        ..values[AppStorage.settingsKey] = '[1,2]';
      final store = TrackerStore();
      final settings = AppSettings();
      await AppStorage(store, settings, backend: disk).start();
      expect(store.pointCount, 0);
      expect(settings.theme, AppThemeChoice.auto);
    });
  });
}

class _CountingStorage extends MemoryStorage {
  int writes = 0;

  @override
  Future<void> write(String key, String value) {
    writes++;
    return super.write(key, value);
  }
}
