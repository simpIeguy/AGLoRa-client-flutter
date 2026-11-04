import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/map/map_markers.dart';
import 'package:tsp_tracker/ui/screens/map_screen.dart';
import 'package:tsp_tracker/ui/screens/tracker_screen.dart';

import 'helpers.dart';

/// the chips of the panel sit in a row that scrolls
Future<void> scrollChipsTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 80,
      scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.horizontal));
  await tester.ensureVisible(find.text(text));
  await tester.pump();
}

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
    await scrollChipsTo(tester, 'Человек 2');
    expect(find.text('Человек 2'), findsOneWidget);
    expect(find.text('БЛА 1 UAV1'), findsOneWidget);
    // no line until asked: the distance only on the card
    expect(find.text('1,4 км'), findsOneWidget);
  });

  testWidgets('"Следить": the map goes to the new point, a finger stops it',
      (tester) async {
    resetApp();
    await show(tester, chosen: 'UAV1');
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final controller = map.mapController!;

    await tester.tap(find.byTooltip('Карта следует за трекером'));
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
    expect(find.byTooltip('Карта следует за трекером'), findsOneWidget,
        reason: 'a finger moved the map: not following any more');
  });

  testWidgets('"Показать на карте" of a tracker follows it at once',
      (tester) async {
    resetApp();
    await show(tester, chosen: 'UAV1', followChosen: true);
    expect(find.byTooltip('Карта не следует за трекером'), findsOneWidget);
    expect(find.byTooltip('Карта следует за трекером'), findsNothing);
  });

  testWidgets('the map button of the main screen does not follow',
      (tester) async {
    resetApp();
    await show(tester, chosen: 'UAV1');
    expect(find.byTooltip('Карта следует за трекером'), findsOneWidget);
  });

  group('landmarks', () {
    Future<void> openSheet(WidgetTester tester, {bool add = false}) async {
      await tester.tap(find.byTooltip('Метки'));
      await tester.pumpAndSettle();
      if (add) {
        await tester.tap(find.text('Добавить метку'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('typed coordinates become a flag on the map', (tester) async {
      resetApp();
      await show(tester, chosen: 'UAV1');
      await openSheet(tester, add: true);
      await tester.enterText(find.byType(TextField).first, '53.9100, 27.5700');
      await tester.pump();
      expect(find.text('Понял как: WGS 84, градусы'), findsOneWidget);

      await tester.tap(find.text('Добавить на карту'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Метка 1'), findsOneWidget);
      expect(app.settings.landmarks.single.latitude, closeTo(53.91, 1e-9));
    });

    testWidgets('СК-42 text and a name of its own', (tester) async {
      resetApp();
      await show(tester, chosen: 'UAV1');
      await openSheet(tester, add: true);
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
      await openSheet(tester, add: true);
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

      await tester.drag(find.text('Сбор').last, const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('Удалить метку?'), findsOneWidget);
      expect(app.settings.landmarks, isNotEmpty, reason: 'asked first');
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(app.settings.landmarks, isEmpty);
      expect(find.text('Пока нет ни одной метки'), findsOneWidget);

      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(app.settings.landmarks.single.name, 'Сбор');
    });

    testWidgets('the list shows the distance, the button leads the line',
        (tester) async {
      resetApp(
          positions: Stream.value(PhonePosition(
              latitude: 53.8945,
              longitude: 27.5440,
              accuracy: 6,
              time: DateTime.now())));
      app.settings.addLandmark('Далеко', 53.95, 27.6);
      app.settings.addLandmark('Сбор', 53.9, 27.55);
      await show(tester, chosen: 'UAV1');
      await openSheet(tester);
      expect(find.textContaining('Сбор  ·  '), findsOneWidget);
      expect(tester.getTopLeft(find.textContaining('Сбор  ·  ')).dy,
          lessThan(tester.getTopLeft(find.textContaining('Далеко  ·  ')).dy),
          reason: 'nearest first');
      await tester.tap(find.byTooltip('Линия до метки').first);
      await tester.pump();
      expect(find.byTooltip('Убрать линию до метки'), findsOneWidget);
    });

    testWidgets('a long press changes a landmark', (tester) async {
      resetApp();
      app.settings.addLandmark('Сбор', 53.903, 27.553);
      await show(tester, chosen: 'UAV1');
      await openSheet(tester);
      await tester.longPress(find.text('Сбор').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Опушка');
      await tester.pump();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(app.settings.landmarks.single.name, 'Опушка');
      expect(app.settings.landmarks.single.latitude, closeTo(53.903, 1e-6));
    });

    testWidgets('the same place or the same name is not added twice',
        (tester) async {
      resetApp();
      app.settings.addLandmark('Сбор', 53.9, 27.55);
      await show(tester, chosen: 'UAV1');
      await openSheet(tester, add: true);
      await tester.enterText(find.byType(TextField).first, '53.9, 27.55');
      await tester.pump();
      expect(find.text('Здесь уже есть метка «Сбор»'), findsOneWidget);
      FilledButton add() => tester.widget<FilledButton>(find.ancestor(
          of: find.text('Добавить на карту'),
          matching: find.byType(FilledButton)));
      expect(add().onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, '53.95, 27.6');
      await tester.enterText(find.byType(TextField).last, ' сбор ');
      await tester.pump();
      expect(find.text('Метка с таким названием уже есть'), findsOneWidget);
      expect(add().onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'Опушка');
      await tester.pump();
      expect(add().onPressed, isNotNull);
    });

    testWidgets('the eye hides a landmark from the map, not from the list',
        (tester) async {
      resetApp();
      app.settings.addLandmark('Сбор', 53.903, 27.553);
      await show(tester, chosen: 'UAV1');
      await openSheet(tester);
      await tester.tap(find.byTooltip('Скрыть метку с карты'));
      await tester.pump();
      expect(app.settings.landmarks.single.visible, isFalse);
      expect(find.text('Сбор'), findsOneWidget, reason: 'only the row');
      expect(find.byTooltip('Показать метку на карте'), findsOneWidget);
      await tester.tap(find.text('Показать все'));
      await tester.pump();
      expect(app.settings.landmarks.single.visible, isTrue);
      expect(find.text('Сбор'), findsNWidgets(2));
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
      // no line yet: only the card of the tracker has the distance
      expect(find.text('1,4 км'), findsOneWidget);
      await tester.tap(find.text('Сбор'));
      await tester.pump();
      expect(find.textContaining(RegExp(r'^7\d\d м$')), findsOneWidget,
          reason: 'the line to the landmark');
      await tester.tap(find.text('Сбор'));
      await tester.pump();
      expect(find.textContaining(RegExp(r'^7\d\d м$')), findsNothing);
    });

    testWidgets('a hidden landmark is not drawn even when the line leads to it',
        (tester) async {
      resetApp(
          positions: Stream.value(PhonePosition(
              latitude: 53.8945,
              longitude: 27.5440,
              accuracy: 6,
              time: DateTime.now())));
      final l = app.settings.addLandmark('Сбор', 53.9, 27.55);
      await show(tester, chosen: 'UAV1');
      await tester.tap(find.text('Сбор'));
      await tester.pump();
      app.settings.setLandmarkVisible(l.id, false);
      await tester.pump();
      expect(find.text('Сбор'), findsNothing, reason: 'the flag is hidden');
      expect(find.textContaining(RegExp(r'^7\d\d м$')), findsOneWidget,
          reason: 'the line stays');
    });

    testWidgets('one aim at a time: a tracker or a landmark', (tester) async {
      resetApp(
          positions: Stream.value(PhonePosition(
              latitude: 53.8945,
              longitude: 27.5440,
              accuracy: 6,
              time: DateTime.now())));
      app.settings.addLandmark('Сбор', 53.9, 27.55);
      await show(tester, chosen: 'UAV1');
      final aim = find.descendant(
          of: find
              .ancestor(
                  of: find.text('Линия до трекера'), matching: find.byType(Row))
              .first,
          matching: find.byType(Switch));
      await tester.tap(aim);
      await tester.pump();
      expect(find.text('1,4 км'), findsNWidgets(2),
          reason: 'the line and the card');

      await tester.tap(find.text('Сбор'));
      await tester.pump();
      expect(tester.widget<Switch>(aim).value, isFalse,
          reason: 'the landmark took the aim');
      expect(find.text('1,4 км'), findsOneWidget);

      await tester.tap(aim);
      await tester.pump();
      expect(find.textContaining(RegExp(r'^7\d\d м$')), findsNothing,
          reason: 'back to the tracker');
      expect(find.text('1,4 км'), findsNWidgets(2));
    });
  });

  testWidgets('+ and − zoom the map by a step', (tester) async {
    resetApp();
    await show(tester);
    final controller =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    final before = controller.zoom;
    await tester.tap(find.byTooltip('Приблизить карту'));
    await tester.pump();
    expect(controller.zoom, before + 1);
    await tester.tap(find.byTooltip('Отдалить карту'));
    await tester.tap(find.byTooltip('Отдалить карту'));
    await tester.pump();
    expect(controller.zoom, before - 1);
  });

  testWidgets('a chip chooses another tracker, its card opens its screen',
      (tester) async {
    resetApp();
    await show(tester);

    // the chips scroll: this one is past the edge now
    await scrollChipsTo(tester, 'Человек 2');
    await tester.tap(find.text('Человек 2'));
    await tester.pump();
    expect(find.text('Человек 2 GROUND2'), findsOneWidget);
    expect(find.text('БЛА 1 UAV1'), findsNothing);

    await tester.tap(find.text('Человек 2 GROUND2'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackerScreen), findsOneWidget);
  });

  testWidgets('the own tracker is on the map, and off when asked',
      (tester) async {
    resetApp();
    feed(memoryMessage('GROUND2'));
    await show(tester, chosen: 'UAV1');
    expect(find.textContaining(RegExp(r'^Вы · ')), findsOneWidget);
    expect(find.text('Вы'), findsOneWidget, reason: 'the chip');
    app.settings.showMyTracker = false;
    await tester.pump();
    expect(find.textContaining(RegExp(r'^Вы · ')), findsNothing);
    expect(find.text('Вы'), findsNothing, reason: 'no chip either');
  });

  testWidgets('one list takes trackers off the map, "Все" brings them back',
      (tester) async {
    resetApp();
    await show(tester, chosen: 'UAV1');
    await tester.tap(find.byTooltip('Какие трекеры показывать'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'БЛА 3'));
    await tester.pump();
    expect(app.settings.isOnMap('UAV3', mine: false), isFalse);
    expect(app.settings.isOnMap('UAV1', mine: false), isTrue);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Все'));
    await tester.pump();
    expect(app.settings.isOnMap('UAV3', mine: false), isTrue,
        reason: 'one was off: "Все" brings it back');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Все'));
    await tester.pump();
    expect(app.settings.isOnMap('UAV1', mine: false), isFalse,
        reason: 'all were on: "Все" takes them all off');
  });

  testWidgets('every tracker off the map: the way back stays', (tester) async {
    resetApp();
    await show(tester);
    await tester.tap(find.byTooltip('Какие трекеры показывать'));
    await tester.pumpAndSettle();
    final all = find.widgetWithText(CheckboxListTile, 'Все');
    await tester.tap(all);
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Все трекеры скрыты с карты'), findsOneWidget);
    await tester.tap(find.byTooltip('Какие трекеры показывать'));
    await tester.pumpAndSettle();
    await tester.tap(all);
    await tester.pump();
    expect(app.settings.isOnMap('UAV1', mine: false), isTrue);
  });

  testWidgets('a sheet goes away with a swipe down, from the list too',
      (tester) async {
    resetApp();
    await show(tester, chosen: 'UAV1');
    await tester.tap(find.byTooltip('Какие трекеры показывать'));
    await tester.pumpAndSettle();
    expect(find.text('Какие трекеры показывать на карте'), findsOneWidget);
    await tester.drag(
        find.text('Какие трекеры показывать на карте'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Какие трекеры показывать на карте'), findsNothing);
  });

  testWidgets('the bottom panel folds to one line and unfolds', (tester) async {
    resetApp();
    await show(tester, chosen: 'UAV1');
    expect(find.text('БЛА 1 UAV1'), findsOneWidget, reason: 'the card');
    await tester.tap(find.byTooltip('Свернуть панель'));
    await tester.pump();
    expect(find.text('БЛА 1 UAV1'), findsNothing);
    expect(find.text('БЛА 1'), findsOneWidget, reason: 'the folded line');
    expect(find.text('Линия до трекера'), findsNothing);
    await tester.tap(find.byTooltip('Развернуть панель'));
    await tester.pump();
    expect(find.text('БЛА 1 UAV1'), findsOneWidget);
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
    await tester.tap(find.byType(Switch).last);
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
