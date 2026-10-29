import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/tracker_status.dart';
import 'package:tsp_tracker/data/tracker_store.dart';
import 'package:tsp_tracker/protocol/tracker_point.dart';
import 'package:tsp_tracker/ui/format.dart';
import 'package:tsp_tracker/ui/screens/settings_screen.dart';
import 'package:tsp_tracker/ui/screens/tracker_screen.dart';
import 'package:tsp_tracker/ui/strings.dart';

import 'helpers.dart';

TrackerPoint pointAt(String name, DateTime time) =>
    TrackerPoint(identifier: name, latitude: 53.9, longitude: 27.5, time: time);

void main() {
  final now = DateTime.now().toUtc();

  group('coordinates', () {
    test('degrees, minutes, seconds as in the mockup', () {
      expect(formatCoordinates(53.90228, 27.56183, CoordinateFormat.dms),
          '53°54′08″N 27°33′43″E');
      expect(formatCoordinates(-33.85678, -70.65, CoordinateFormat.dms),
          '33°51′24″S 70°39′00″W');
      // 59.9999999° rounds up to a whole degree, not to "59°60′"
      expect(formatCoordinates(59.9999999, 30, CoordinateFormat.dms),
          '60°00′00″N 30°00′00″E');
      expect(formatCoordinates(53.90228, 27.56183), '53.90228, 27.56183');
    });
  });

  group('thresholds of the link', () {
    test('the statuses follow the chosen thresholds', () {
      final store = TrackerStore(now: () => now)
        ..addPoint(pointAt('UAV1', now.subtract(const Duration(seconds: 90))));
      expect(store.statusOf('UAV1', now), TrackerStatus.fading);
      expect(
          store.setThresholds(fadingAfter: const Duration(minutes: 2)), isTrue);
      expect(store.statusOf('UAV1', now), TrackerStatus.active);
      expect(
          store.setThresholds(lostAfter: const Duration(minutes: 2)), isFalse,
          reason: '"пропадает" must come before "потеряна"');
      expect(store.lostAfter, const Duration(minutes: 5));
      expect(store.statusOf('nobody', now), TrackerStatus.waiting);
    });

    test('clearing keeps the connected tracker', () {
      final store = TrackerStore(now: () => now)
        ..setConnectedTracker('GROUND1')
        ..addPoint(pointAt('UAV1', now))
        ..setAlias('UAV1', 'Крыло');
      store.clearTrackers();
      expect(store.pointsOf('UAV1'), isEmpty);
      expect(store.aliasOf('UAV1'), isNull);
      expect(store.connectedTracker, 'GROUND1');
    });
  });

  test('the version on the settings screen is the one in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([\d.]+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    expect(S.appVersion, version);
  });

  group('the screen', () {
    setUp(resetApp);

    Future<void> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(inApp(const SettingsScreen()));
    }

    testWidgets('the coordinate format changes the other screens',
        (tester) async {
      await show(tester);
      expect(find.text('Язык'), findsNothing);
      expect(find.textContaining('AGLoRa'), findsNothing);
      expect(find.text('Поиск БЛА 1.0.0'), findsOneWidget);

      await tester.tap(find.text('Градусы, минуты, секунды (DMS), WGS 84'));
      await tester.pump();

      feed(pointMessage('UAV1', 53.90228, 27.56183, now, index: 0));
      await tester.pumpWidget(inApp(const TrackerScreen(identifier: 'UAV1')));
      await tester.pump();
      expect(find.text('53°54′08″N 27°33′43″E'), findsWidgets);
    });

    testWidgets('a threshold from the list; a clash is not offered',
        (tester) async {
      await show(tester);
      await tester.tap(find.text('Связь пропадает после'));
      await tester.pumpAndSettle();
      // 5 min "пропадает" with 5 min "потеряна" would mix them up
      final five = tester.widget<ListTile>(find.ancestor(
          of: find.text('5 мин').last, matching: find.byType(ListTile)));
      expect(five.enabled, isFalse);
      await tester.tap(find.text('2 мин'));
      await tester.pumpAndSettle();
      expect(app.store.fadingAfter, const Duration(minutes: 2));
      expect(find.text('2 мин'), findsOneWidget);
    });

    testWidgets('switches: new UAVs, the screen kept on', (tester) async {
      await show(tester);
      await tester.tap(find.text('О каждом новом БЛА'));
      await tester.tap(find.text('Не гасить в полном экране'));
      await tester.pump();
      expect(app.store.alertNewUavs, isFalse);
      expect(app.settings.keepScreenOn, isFalse);
      expect(find.text('Слежение при выключенном экране'), findsNothing);
    });

    testWidgets('clearing the memory asks first', (tester) async {
      feed(pointMessage('UAV1', 53.9, 27.5, now, index: 0));
      await show(tester);
      await tester.tap(find.text('Очистить память приложения'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить все трекеры и точки?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(app.store.pointCount, 1);

      await tester.tap(find.text('Очистить память приложения'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(app.store.pointCount, 0);
      expect(find.text('Память очищена'), findsOneWidget);
    });
  });
}
