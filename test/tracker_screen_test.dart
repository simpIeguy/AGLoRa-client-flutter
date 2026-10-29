import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/format.dart';
import 'package:tsp_tracker/ui/screens/full_screen_arrow.dart';
import 'package:tsp_tracker/ui/screens/tracker_screen.dart';

import 'helpers.dart';

void main() {
  setUp(resetApp);
  final now = DateTime.now().toUtc();

  /// [count] points 30 s apart, the newest [now]
  void feedPoints(String name, int count) {
    for (int i = count - 1; i >= 0; i--) {
      feed(pointMessage(
          name, 53.9 + i / 1000, 27.5, now.subtract(Duration(seconds: 30 * i)),
          index: count - 1 - i));
    }
  }

  Future<void> show(WidgetTester tester, String identifier) async {
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(inApp(TrackerScreen(identifier: identifier)));
    await tester.pump();
  }

  testWidgets('the state of the tracker, no battery', (tester) async {
    feedPoints('UAV1', 1);
    await show(tester, 'UAV1');

    expect(find.text('БЛА 1 UAV1'), findsOneWidget);
    expect(find.text('Связь есть'), findsOneWidget);
    expect(find.text('Координаты верные'), findsOneWidget);
    expect(find.text('Спутники'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('120,5 м'), findsOneWidget);
    expect(find.text('Время GPS'), findsOneWidget);
    expect(find.text(formatClock(now.toLocal())), findsWidgets);
    expect(find.textContaining('87'), findsNothing,
        reason: 'no battery: the firmware always sends a made-up value');
    expect(find.text('Поделиться'), findsNothing);
  });

  testWidgets('the points in a window of five that scrolls', (tester) async {
    feedPoints('UAV1', 8);
    await show(tester, 'UAV1');

    expect(find.text('Точки: 8'), findsOneWidget);
    // the newest twice: on the card and in the list
    expect(find.text('53.90000, 27.50000'), findsNWidgets(2));
    expect(find.text('53.90400, 27.50000'), findsOneWidget);
    expect(find.text('53.90700, 27.50000'), findsNothing);

    // scrolled inside its window, the screen stays as it was
    final title = tester.getTopLeft(find.text('Точки: 8'));
    await tester.drag(find.text('53.90300, 27.50000'), const Offset(0, -300));
    await tester.pump();
    expect(find.text('53.90700, 27.50000'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Точки: 8')), title);
  });

  testWidgets('no fix now: says so, the satellites of an old point hidden',
      (tester) async {
    feedPoints('UAV2', 1);
    feed(pointMessage('UAV2', 0, 0, now, index: 1));
    await show(tester, 'UAV2');

    expect(find.text('Нет спутников, показана последняя верная точка'),
        findsOneWidget);
    expect(find.textContaining('· Нет спутников'), findsOneWidget,
        reason: 'under the status, as on the card');
    expect(find.text('Спутники'), findsNothing);
    expect(find.text('53.90000, 27.50000'), findsNWidgets(2));
  });

  testWidgets('heard only without a fix: no coordinates, no map button',
      (tester) async {
    feed(pointMessage('UAV3', 0, 0, now, index: 0));
    await show(tester, 'UAV3');

    expect(find.text('Трекер ищет спутники'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Открыть в картах'), findsNothing);
    expect(find.text('Точек пока нет'), findsOneWidget);
  });

  testWidgets('rename, and an empty name brings back the firmware one',
      (tester) async {
    feedPoints('UAV1', 1);
    await show(tester, 'UAV1');

    await tester.tap(find.byTooltip('Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Крыло');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(app.store.aliasOf('UAV1'), 'Крыло');
    expect(find.text('Крыло UAV1'), findsOneWidget);

    await tester.tap(find.byTooltip('Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(app.store.aliasOf('UAV1'), isNull);
    expect(find.text('БЛА 1 UAV1'), findsOneWidget);
  });

  testWidgets('remove asks first', (tester) async {
    feedPoints('GROUND2', 2);
    await tester.pumpWidget(inApp(Builder(
        builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TrackerScreen(identifier: 'GROUND2'))),
            child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // the screen, not the points' window inside it
    await tester.scrollUntilVisible(find.text('Удалить трекер из списка'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Удалить трекер из списка'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Удалить Человек 2 и все его точки?'),
        findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(app.store.pointsOf('GROUND2'), hasLength(2));

    await tester.tap(find.text('Удалить трекер из списка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(app.store.pointsOf('GROUND2'), isEmpty);
    expect(find.byType(TrackerScreen), findsNothing);
  });

  testWidgets('the azimuth, and a tap on the arrow opens the full screen',
      (tester) async {
    final positions = StreamController<PhonePosition>();
    final readings = StreamController<CompassReading>();
    resetApp(positions: positions.stream, compass: readings.stream);
    feed(pointMessage('UAV1', 53.91, 27.57, now, index: 0));
    await show(tester, 'UAV1');
    expect(find.text('Нет GPS телефона'), findsOneWidget);

    positions.add(PhonePosition(
        latitude: 53.90, longitude: 27.57, accuracy: 6, time: DateTime.now()));
    readings.add(const CompassReading(0, accuracy: 15));
    await tester.pump();
    await tester.pump();
    expect(find.text('азимут 0° С'), findsOneWidget);

    await tester.tap(find
        .bySemanticsLabel('Направление на БЛА 1, нажмите для полного экрана'));
    await tester.pumpAndSettle();
    expect(find.byType(FullScreenArrow), findsOneWidget);

    await positions.close();
    await readings.close();
  });
}
