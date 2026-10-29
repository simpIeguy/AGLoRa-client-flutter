import 'package:flutter/material.dart';
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
