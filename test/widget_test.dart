import 'package:tsp_tracker/aglora/memory.dart';
import 'package:tsp_tracker/screens/screen_device.dart';
import 'package:tsp_tracker/screens/screen_tracker_log.dart';
import 'package:tsp_tracker/utils/tracker_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(resetApp);

  Future<void> showTrackers(WidgetTester tester) async {
    final now = DateTime.now().toUtc();
    feed(memoryMessage('Tracker1'));
    feed(pointMessage('Tracker1', 53.902284, 27.561831, now));
    feed(pointMessage(
        'Tracker2', 53.91, 27.57, now.subtract(Duration(minutes: 2)),
        index: 0));
    await tester
        .pumpWidget(MaterialApp(home: DeviceScreen(demoTitle: 'Демо: тест')));
    await tester.pump(Duration(seconds: 1));
  }

  Color cardColor(WidgetTester tester, String name) {
    final card = find
        .ancestor(of: find.text(name), matching: find.byType(Container))
        .evaluate()
        .map((e) => e.widget as Container)
        .firstWhere((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).borderRadius != null);
    return (card.decoration as BoxDecoration).color!;
  }

  testWidgets('tracker cards: blue for the connected one, yellow when late',
      (tester) async {
    await showTrackers(tester);

    expect(find.text('Демо: тест'), findsOneWidget);
    expect(find.text('Tracker1'), findsOneWidget);
    expect(find.text('Tracker2'), findsOneWidget);
    expect(cardColor(tester, 'Tracker1'),
        trackerStatusColor(TrackerStatus.connected));
    expect(cardColor(tester, 'Tracker2'),
        trackerStatusColor(TrackerStatus.fading));
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
    await tester.pumpAndSettle(Duration(milliseconds: 100));
    expect(find.byType(TrackerLogScreen), findsOneWidget);
    expect(find.text('Лог: Tracker1'), findsOneWidget);

    await tester.longPress(find.text('53.902284, 27.561831'));
    await tester.pump();
    expect(copied, '53.902284, 27.561831');
    expect(find.text('Скопировано'), findsOneWidget);

    expect(agloraAppMemory.pointsOf('Tracker1'), hasLength(1));
    await tester.pumpWidget(SizedBox.shrink());
  });
}
