import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/map_screen.dart';
import 'package:tsp_tracker/ui/screens/tracker_screen.dart';

import 'helpers.dart';

void main() {
  final now = DateTime.now().toUtc();

  Future<void> show(WidgetTester tester, {String? chosen}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    feed(pointMessage('UAV1', 53.902, 27.562, now, index: 0));
    feed(pointMessage(
        'UAV3', 53.925, 27.544, now.subtract(const Duration(minutes: 14)),
        index: 1));
    feed(pointMessage('GROUND2', 53.890, 27.548, now, index: 2));
    await tester.pumpWidget(inApp(MapScreen(
        centerLatitude: 53.9,
        centerLongitude: 27.55,
        chosen: chosen,
        withTiles: false)));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('labels on the map, the most important tracker chosen',
      (tester) async {
    resetApp(
        positions: Stream.value(PhonePosition(
            latitude: 53.8945,
            longitude: 27.5440,
            accuracy: 6,
            time: DateTime.now())),
        compass: Stream.value(const CompassReading(30, accuracy: 15)));
    await show(tester);

    expect(find.textContaining(RegExp(r'^БЛА 1 · \d+ с$')), findsOneWidget);
    expect(find.text('БЛА 3 · 14 мин'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Человек 2 · \d+ с$')), findsOneWidget);
    // the chips and the card of the chosen one
    expect(find.text('Человек 2'), findsOneWidget);
    expect(find.text('БЛА 1 UAV1'), findsOneWidget);
    // the line's label and the card: the same distance
    expect(find.text('1,4 км'), findsNWidgets(2));
  });

  testWidgets('"Следить": the map goes to the new point, a finger stops it',
      (tester) async {
    resetApp();
    await show(tester, chosen: 'UAV1');
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final controller = map.mapController!;

    await tester.tap(find.byTooltip('Следить за выбранным'));
    await tester.pump();
    await tester.pump();
    expect(controller.center.latitude, closeTo(53.902, 0.0001));

    feed(pointMessage('UAV1', 53.95, 27.6, now.add(const Duration(seconds: 30)),
        index: 3));
    await tester.pump();
    await tester.pump();
    expect(controller.center.latitude, closeTo(53.95, 0.0001),
        reason: 'a new point: the map follows');

    await tester.drag(find.byType(FlutterMap), const Offset(0, 80));
    await tester.pump();
    expect(find.byTooltip('Следить за выбранным'), findsOneWidget,
        reason: 'a finger moved the map: not following any more');
  });

  testWidgets('a chip chooses another tracker, its card opens its screen',
      (tester) async {
    resetApp();
    await show(tester);

    await tester.tap(find.text('Человек 2'));
    await tester.pump();
    expect(find.text('Человек 2 GROUND2'), findsOneWidget);
    expect(find.text('БЛА 1 UAV1'), findsNothing);

    await tester.tap(find.text('Человек 2 GROUND2'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackerScreen), findsOneWidget);
  });

  testWidgets('the phone\'s own tracker is "Вы", not "Человек 2"',
      (tester) async {
    resetApp();
    feed(memoryMessage('GROUND2'));
    await show(tester, chosen: 'GROUND2');
    expect(find.textContaining(RegExp(r'^Вы · \d+ с$')), findsOneWidget);
    expect(find.text('Вы'), findsOneWidget, reason: 'the chip');
    expect(find.text('Вы GROUND2'), findsOneWidget, reason: 'the card');
    expect(find.textContaining('Человек 2'), findsNothing);
  });

  testWidgets('"След": all tracks drawn, one can be switched off',
      (tester) async {
    resetApp();
    feed(pointMessage(
        'UAV1', 53.900, 27.562, now.subtract(const Duration(seconds: 30)),
        index: 10));
    await show(tester);
    expect(find.byType(PolylineLayer), findsOneWidget,
        reason: 'UAV1 has two points: a track');

    await tester.tap(find.byTooltip('След'));
    await tester.pumpAndSettle();
    expect(find.text('Чьи следы показывать'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'БЛА 1'));
    await tester.pump();
    expect(app.settings.isTrackShown('UAV1'), isFalse);
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets(
      '"Все" unticks every track at once, the card\'s switch the chosen',
      (tester) async {
    resetApp();
    feed(pointMessage(
        'UAV1', 53.900, 27.562, now.subtract(const Duration(seconds: 30)),
        index: 10));
    await show(tester);
    expect(find.byType(PolylineLayer), findsOneWidget);

    await tester.tap(find.byTooltip('След'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Все'));
    await tester.pump();
    for (final key in ['UAV1', 'UAV3', 'GROUND2']) {
      expect(app.settings.isTrackShown(key), isFalse, reason: key);
    }
    expect(find.byType(PolylineLayer), findsNothing);

    // tick all again, close the list
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Все'));
    await tester.pump();
    expect(app.settings.isTrackShown('UAV1'), isTrue);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // the switch in the card of the chosen tracker (UAV1)
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(app.settings.isTrackShown('UAV1'), isFalse);
    expect(app.settings.isTrackShown('GROUND2'), isTrue);
  });

  testWidgets('chosen from the outside; "Где я" without GPS says so',
      (tester) async {
    resetApp();
    await show(tester, chosen: 'uav 3');
    expect(find.text('БЛА 3 UAV3'), findsOneWidget);

    await tester.tap(find.byTooltip('Где я'));
    await tester.pump();
    expect(find.text('Нет GPS телефона'), findsWidgets);
  });
}
