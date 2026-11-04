import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/map/map_markers.dart';
import 'package:tsp_tracker/ui/screens/map_screen.dart';
import 'package:tsp_tracker/ui/screens/tracker_screen.dart';

import 'helpers.dart';

void main() {
  final now = DateTime.now().toUtc();

  Future<void> show(WidgetTester tester,
      {String? chosen, bool followChosen = false}) async {
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
        followChosen: followChosen,
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

  testWidgets('"Показать на карте" of a tracker follows it at once',
      (tester) async {
    resetApp();
    await show(tester, chosen: 'UAV1', followChosen: true);
    expect(find.byTooltip('Не следить'), findsOneWidget);
    expect(find.byTooltip('Следить за выбранным'), findsNothing);
  });

  testWidgets('the map button of the main screen does not follow',
      (tester) async {
    resetApp();
    await show(tester, chosen: 'UAV1');
    expect(find.byTooltip('Следить за выбранным'), findsOneWidget);
  });

  group('landmarks', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Ориентиры'));
      await tester.pumpAndSettle();
    }

    testWidgets('typed coordinates become a flag on the map', (tester) async {
      resetApp();
      await show(tester, chosen: 'UAV1');
      await openSheet(tester);
      await tester.enterText(find.byType(TextField).first, '53.9100, 27.5700');
      await tester.pump();
      expect(find.text('Понял как: WGS 84, градусы'), findsOneWidget);

      await tester.tap(find.text('Добавить на карту'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Ориентир 1'), findsOneWidget);
      expect(app.settings.landmarks.single.latitude, closeTo(53.91, 1e-9));
    });

    testWidgets('СК-42 text and a name of its own', (tester) async {
      resetApp();
      await show(tester, chosen: 'UAV1');
      await openSheet(tester);
      await tester.enterText(
          find.byType(TextField).first, 'X 5975056 Y 5536935');
      await tester.pump();
      expect(
          find.text('Понял как: СК-42, прямоугольные, зона 5'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Опушка');
      await tester.tap(find.text('Добавить на карту'));
      await tester.pumpAndSettle();
      expect(find.text('Опушка'), findsOneWidget);
      expect(app.settings.landmarks.single.latitude, closeTo(53.9, 2e-4));
    });

    testWidgets('not understood: said so, nothing to add', (tester) async {
      resetApp();
      await show(tester, chosen: 'UAV1');
      await openSheet(tester);
      await tester.enterText(find.byType(TextField).first, 'вон там');
      await tester.pump();
      expect(find.textContaining('Не понял координаты'), findsOneWidget);
      final add = tester.widget<FilledButton>(find.ancestor(
          of: find.text('Добавить на карту'),
          matching: find.byType(FilledButton)));
      expect(add.onPressed, isNull);
    });

    testWidgets('the list: go to a landmark, delete it', (tester) async {
      resetApp();
      app.settings.addLandmark('Сбор', 53.903, 27.553);
      await show(tester, chosen: 'UAV1');
      expect(find.text('Сбор'), findsOneWidget, reason: 'the flag');
      await openSheet(tester);
      expect(find.text('Сбор'), findsNWidgets(2),
          reason: 'the flag and the row');

      await tester.tap(find.byTooltip('Удалить ориентир'));
      await tester.pumpAndSettle();
      expect(app.settings.landmarks, isEmpty);
      expect(find.text('Пока нет ни одного ориентира'), findsOneWidget);
    });

    testWidgets('a tap on a flag sends the line to it, and back',
        (tester) async {
      resetApp(
          positions: Stream.value(PhonePosition(
              latitude: 53.8945,
              longitude: 27.5440,
              accuracy: 6,
              time: DateTime.now())));
      app.settings.addLandmark('Сбор', 53.9, 27.55);
      await show(tester, chosen: 'UAV1');
      // the line and the card of the tracker
      expect(find.text('1,4 км'), findsNWidgets(2));
      await tester.tap(find.text('Сбор'));
      await tester.pump();
      expect(find.text('1,4 км'), findsOneWidget, reason: 'only the card');
      expect(find.textContaining(RegExp(r'^7\d\d м$')), findsOneWidget,
          reason: 'the line to the landmark');
      await tester.tap(find.text('Сбор'));
      await tester.pump();
      expect(find.text('1,4 км'), findsNWidgets(2));
    });
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

  testWidgets('the own tracker is off the map until asked; the button toggles',
      (tester) async {
    resetApp();
    feed(memoryMessage('GROUND2'));
    await show(tester, chosen: 'UAV1');
    expect(find.textContaining(RegExp(r'^Вы · ')), findsNothing);
    expect(find.text('Вы'), findsNothing, reason: 'no chip either');

    await tester.tap(find.byTooltip('Показать мой трекер на карте'));
    await tester.pump();
    expect(find.textContaining(RegExp(r'^Вы · \d+ с$')), findsOneWidget);
    expect(find.text('Вы'), findsOneWidget);

    await tester.tap(find.byTooltip('Скрыть мой трекер с карты'));
    await tester.pump();
    expect(find.textContaining(RegExp(r'^Вы · ')), findsNothing);
  });

  testWidgets('no button for the own tracker when none is connected',
      (tester) async {
    resetApp();
    await show(tester);
    expect(find.byTooltip('Показать мой трекер на карте'), findsNothing);
  });

  testWidgets('the phone walking: the map shows without a fault',
      (tester) async {
    resetApp(
        positions: Stream.value(PhonePosition(
            latitude: 53.8945,
            longitude: 27.5440,
            accuracy: 6,
            speed: 1.4,
            course: 45,
            time: DateTime.now())));
    await show(tester);
    expect(tester.takeException(), isNull);
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PhonePainter>();
    expect(painters.single.course, 45);
  });

  testWidgets('the phone standing: no walking arrow', (tester) async {
    resetApp(
        positions: Stream.value(PhonePosition(
            latitude: 53.8945,
            longitude: 27.5440,
            accuracy: 6,
            speed: 0.3,
            course: 45,
            time: DateTime.now())));
    await show(tester);
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PhonePainter>();
    expect(painters.single.course, isNull);
  });

  testWidgets('the phone\'s own tracker is "Вы", not "Человек 2"',
      (tester) async {
    resetApp();
    app.settings.showMyTracker = true;
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
