import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/protocol/tracker_name.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/full_screen_arrow.dart';
import 'package:tsp_tracker/ui/screens/tracker_screen.dart';
import 'package:tsp_tracker/ui/screens/trackers_screen.dart';
import 'package:tsp_tracker/ui/theme.dart';
import 'package:tsp_tracker/ui/widgets/direction_arrow.dart';
import 'package:tsp_tracker/ui/widgets/first_signal_alerts.dart';
import 'package:tsp_tracker/ui/widgets/status_dot.dart';

import 'helpers.dart';

void main() {
  setUp(resetApp);

  Future<void> showTrackers(WidgetTester tester) async {
    final now = DateTime.now().toUtc();
    feed(memoryMessage('GROUND1'));
    feed(pointMessage('GROUND1', 53.902284, 27.561831, now));
    feed(pointMessage(
        'UAV1', 53.91, 27.57, now.subtract(const Duration(minutes: 2)),
        index: 0));
    await tester.pumpWidget(inApp(const TrackersScreen(demoTitle: 'Демо')));
    await tester.pump();
  }

  testWidgets('you at the top, then the groups; neutral cards with a dot',
      (tester) async {
    await showTrackers(tester);

    // the connected tracker is "you", not a card in the groups
    expect(find.text('Вы · GROUND1'), findsOneWidget);
    expect(find.text('Человек 1 GROUND1'), findsNothing);
    expect(find.text('БЛА'), findsOneWidget, reason: 'the group title');
    expect(find.text('БЛА 1 UAV1'), findsOneWidget);
    expect(find.text('Связь пропадает'), findsOneWidget);
    expect(find.byType(StatusDot), findsOneWidget);
    expect(find.textContaining('87'), findsNothing,
        reason: 'no battery: the firmware always sends a made-up value');

    final you = tester.getTopLeft(find.text('Вы · GROUND1')).dy;
    final uav = tester.getTopLeft(find.text('БЛА 1 UAV1')).dy;
    expect(you, lessThan(uav));
  });

  testWidgets('no phone GPS: the reason instead of a distance', (tester) async {
    await showTrackers(tester);
    expect(find.text('—'), findsOneWidget, reason: 'no distance');
    expect(find.text('GPS нет позиции'), findsOneWidget);
    expect(arrowStyles(), contains(ArrowStyle.unavailable),
        reason: 'no direction: a dashed arrow');
  });

  testWidgets('with phone GPS: distance and direction', (tester) async {
    final positions = StreamController<PhonePosition>();
    final readings = StreamController<CompassReading>();
    resetApp(positions: positions.stream, compass: readings.stream);
    await showTrackers(tester);

    positions.add(PhonePosition(
        latitude: 53.90, longitude: 27.57, accuracy: 6, time: DateTime.now()));
    readings.add(const CompassReading(0, accuracy: 15));
    await tester.pump();
    await tester.pump();

    expect(find.text('1,1 км'), findsOneWidget);
    expect(find.text('GPS ±6 м'), findsOneWidget);
    expect(find.text('Компас точный'), findsOneWidget);
    expect(arrowStyles(), contains(ArrowStyle.filled));

    readings.add(const CompassReading(0, accuracy: 45));
    await tester.pump();
    await tester.pump();
    expect(find.text('Компас неточный'), findsOneWidget);
    expect(find.text('Помашите телефоном восьмёркой'), findsOneWidget);
    expect(arrowStyles(), contains(ArrowStyle.outline),
        reason: 'an inaccurate compass: an outline, the color stays');

    // a long press on the arrow opens the full screen
    final arrow = find.bySemanticsLabel(
        'Двойной тап или долгое нажатие на стрелку — полный экран');
    await tester.longPress(arrow);
    await tester.pumpAndSettle();
    expect(find.byType(FullScreenArrow), findsOneWidget);
    expect(find.text('азимут 0° С'), findsOneWidget);
    expect(find.text('53.91000, 27.57000'), findsOneWidget);
    expect(find.text('Компас неточный: помашите телефоном восьмёркой'),
        findsOneWidget);

    // a double tap goes back
    await tester.tap(find.text('Двойной тап — выход'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Двойной тап — выход'));
    await tester.pumpAndSettle();
    expect(find.byType(FullScreenArrow), findsNothing);

    await positions.close();
    await readings.close();
  });

  testWidgets('tap on a card opens its screen, long press copies',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });

    await showTrackers(tester);
    // the coordinates on the card copy with a long press
    await tester.longPress(find.text('53.91000, 27.57000'));
    await tester.pump();
    expect(copied, '53.91000, 27.57000');
    expect(find.text('Скопировано: 53.91000, 27.57000'), findsOneWidget);

    await tester.tap(find.text('БЛА 1 UAV1'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(TrackerScreen), findsOneWidget);
    expect(find.text('Состояние трекера'), findsOneWidget);
  });

  testWidgets('the screen redraws when a point comes', (tester) async {
    await tester.pumpWidget(inApp(const TrackersScreen(demoTitle: 'Демо')));
    expect(find.text('Трекеров пока нет'), findsOneWidget);
    feed(pointMessage('Tracker5', 53.9, 27.5, DateTime.now().toUtc()));
    await tester.pump();
    expect(find.textContaining('Tracker5'), findsOneWidget);
  });

  testWidgets('wait for a tracker: the stub, then the real card',
      (tester) async {
    await tester.pumpWidget(inApp(const TrackersScreen(demoTitle: 'Демо')));
    await tester.tap(find.text('Ждать трекер'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'uav-3');
    await tester.pump();
    expect(find.text('Распознано: UAV3 → БЛА 3'), findsOneWidget);
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();

    expect(find.text('Ждём первый сигнал'), findsOneWidget);

    feed(pointMessage('UAV3', 53.9, 27.5, DateTime.now().toUtc(), index: 0));
    await tester.pump();
    expect(find.text('Ждём первый сигнал'), findsNothing);
    expect(find.text('Связь есть'), findsOneWidget);
  });

  testWidgets('no GPS fix on the tracker: the card says so', (tester) async {
    await tester.pumpWidget(inApp(const TrackersScreen(demoTitle: 'Демо')));
    feed(pointMessage('UAV6', 0, 0, DateTime.now().toUtc(), index: 0));
    await tester.pump();
    expect(find.textContaining('Трекер ищет спутники'), findsOneWidget);
    expect(find.text('Связь есть'), findsOneWidget);

    feed(pointMessage('UAV6', 53.9, 27.5,
        DateTime.now().toUtc().add(const Duration(seconds: 1)),
        index: 1));
    await tester.pump();
    expect(find.textContaining('Трекер ищет спутники'), findsNothing);
  });

  testWidgets('a waited stub can be removed', (tester) async {
    app.store.addWaiting(parseTrackerName('GROUND4'));
    await tester.pumpWidget(inApp(const TrackersScreen(demoTitle: 'Демо')));
    expect(find.textContaining('Человек 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Убрать Человек 4 из ожидания'));
    await tester.pump();
    expect(find.textContaining('Человек 4'), findsNothing);
  });

  testWidgets('the settings switch the theme, night is red', (tester) async {
    await tester.pumpWidget(inApp(const TrackersScreen(demoTitle: 'Демо')));
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ночная'));
    await tester.pumpAndSettle();
    expect(app.settings.theme, AppThemeChoice.night);
    final context = tester.element(find.text('Тема'));
    expect(AppPalette.of(context), AppPalette.night);
  });

  testWidgets('the first signal shows a banner once', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(inApp(
      const TrackersScreen(demoTitle: 'Демо'),
      navigatorKey: navigatorKey,
      messengerKey: messengerKey,
      builder: (context, child) => FirstSignalAlerts(
          navigatorKey: navigatorKey,
          messengerKey: messengerKey,
          child: child!),
    ));

    final now = DateTime.now().toUtc();
    feed(pointMessage('UAV2', 53.9, 27.5, now, index: 0));
    await tester.pumpAndSettle();
    expect(
        find.text('БЛА 2 вышел на связь\n53.90000, 27.50000'), findsOneWidget);

    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    feed(pointMessage('UAV2', 53.91, 27.5, now.add(const Duration(seconds: 30)),
        index: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('вышел на связь'), findsNothing);
  });
}

/// how the arrows on the screen are drawn
List<ArrowStyle> arrowStyles() => [
      for (final e in find.byType(ArrowShape).evaluate())
        (e.widget as ArrowShape).style,
    ];
