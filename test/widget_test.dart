import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/tracker_status.dart';
import 'package:tsp_tracker/ui/screens/tracker_log_screen.dart';
import 'package:tsp_tracker/ui/screens/trackers_screen.dart';
import 'package:tsp_tracker/ui/theme.dart';

import 'helpers.dart';

void main() {
  setUp(resetApp);

  Future<void> showTrackers(WidgetTester tester) async {
    final now = DateTime.now().toUtc();
    feed(memoryMessage('Tracker1'));
    feed(pointMessage('Tracker1', 53.902284, 27.561831, now));
    feed(pointMessage(
        'Tracker2', 53.91, 27.57, now.subtract(const Duration(minutes: 2)),
        index: 0));
    await tester
        .pumpWidget(inApp(const TrackersScreen(demoTitle: 'Демо: тест')));
    await tester.pump();
  }

  Color cardColor(WidgetTester tester, String name) {
    final card = find
        .ancestor(of: find.text(name), matching: find.byType(Material))
        .evaluate()
        .map((e) => e.widget as Material)
        .firstWhere((m) => m.borderRadius != null);
    return card.color!;
  }

  testWidgets('tracker cards: blue for the connected one, yellow when late',
      (tester) async {
    await showTrackers(tester);

    expect(find.text('Демо: тест'), findsOneWidget);
    expect(find.text('Tracker1'), findsOneWidget);
    expect(find.text('Tracker2'), findsOneWidget);
    expect(cardColor(tester, 'Tracker1'),
        AppColors.status(TrackerStatus.connected));
    expect(
        cardColor(tester, 'Tracker2'), AppColors.status(TrackerStatus.fading));
  });

  testWidgets('tap on a card opens its log, long press copies', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });

    await showTrackers(tester);
    await tester.tap(find.text('Tracker1'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(TrackerLogScreen), findsOneWidget);
    expect(find.text('Лог: Tracker1'), findsOneWidget);

    await tester.longPress(find.text('53.902284, 27.561831'));
    await tester.pump();
    expect(copied, '53.902284, 27.561831');
    expect(find.text('Скопировано'), findsOneWidget);

    expect(app.store.pointsOf('Tracker1'), hasLength(1));
  });

  testWidgets('the screen redraws when a point comes', (tester) async {
    await tester.pumpWidget(inApp(const TrackersScreen(demoTitle: 'Демо')));
    expect(find.text('Трекеров пока нет'), findsOneWidget);
    feed(pointMessage('Tracker5', 53.9, 27.5, DateTime.now().toUtc()));
    await tester.pump();
    expect(find.text('Tracker5'), findsOneWidget);
  });
}
