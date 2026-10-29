import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/full_screen_arrow.dart';
import 'package:tsp_tracker/ui/theme.dart';
import 'package:tsp_tracker/ui/widgets/direction_arrow.dart';

import 'helpers.dart';

void main() {
  final now = DateTime.now().toUtc();

  Stream<PhonePosition> phoneAt(double lat, double lon) =>
      Stream.value(PhonePosition(
          latitude: lat, longitude: lon, accuracy: 6, time: DateTime.now()));

  Future<void> show(WidgetTester tester, String identifier) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(inApp(FullScreenArrow(identifier: identifier)));
    await tester.pump();
    await tester.pump();
  }

  List<ArrowStyle> arrowStyles() => [
        for (final e in find.byType(ArrowShape).evaluate())
          (e.widget as ArrowShape).style,
      ];

  testWidgets('the link is there: azimuth and GPS accuracy, a filled arrow',
      (tester) async {
    resetApp(
        positions: phoneAt(53.90, 27.57),
        compass: Stream.value(const CompassReading(0, accuracy: 15)));
    feed(pointMessage('UAV1', 53.91, 27.57, now, index: 0));
    await show(tester, 'UAV1');

    expect(find.text('БЛА 1 UAV1'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Связь есть · \d+ с назад$')),
        findsOneWidget);
    expect(find.text('1,1 км'), findsOneWidget);
    expect(find.text('азимут 0° С · точность GPS ±6\u00A0м'), findsOneWidget);
    expect(arrowStyles(), [ArrowStyle.filled]);
    expect(find.text('Последняя точка'), findsNothing);
  });

  testWidgets('the link is lost: to the last known point', (tester) async {
    resetApp(
        positions: phoneAt(53.90, 27.57),
        compass: Stream.value(const CompassReading(0, accuracy: 15)));
    feed(pointMessage(
        'UAV3', 53.91, 27.57, now.subtract(const Duration(minutes: 14)),
        index: 0));
    await show(tester, 'UAV3');

    expect(find.text('Связь потеряна · 14 мин назад'), findsOneWidget);
    expect(
        find.text('Стрелка ведёт к последней известной точке'), findsOneWidget);
    expect(find.text('Последняя точка'), findsOneWidget);
    expect(arrowStyles(), [ArrowStyle.outline]);
  });

  testWidgets('no phone GPS: the reason, a dashed arrow, "— км"',
      (tester) async {
    resetApp();
    feed(pointMessage('UAV1', 53.91, 27.57, now, index: 0));
    await show(tester, 'UAV1');

    expect(find.text('Нет сигнала GPS'), findsOneWidget);
    expect(find.text('— км'), findsOneWidget);
    expect(find.text('точность GPS: нет данных'), findsOneWidget);
    expect(find.text('Последняя точка БЛА 1'), findsOneWidget);
    expect(arrowStyles(), [ArrowStyle.unavailable]);
  });

  testWidgets('black in the day themes, red in the night one', (tester) async {
    resetApp();
    feed(pointMessage('UAV1', 53.91, 27.57, now, index: 0));
    app.settings.theme = AppThemeChoice.light;
    await show(tester, 'UAV1');
    expect(AppPalette.of(tester.element(find.text('— км'))), AppPalette.full);

    app.settings.theme = AppThemeChoice.night;
    await tester.pumpAndSettle(); // the theme change is animated
    expect(AppPalette.of(tester.element(find.text('— км'))), AppPalette.night);
  });

  testWidgets('the screen is not kept on when switched off', (tester) async {
    resetApp();
    app.settings.keepScreenOn = false;
    feed(pointMessage('UAV1', 53.91, 27.57, now, index: 0));
    await show(tester, 'UAV1');
    expect(screenKept, isEmpty);
  });
}
