import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/ui/screens/wait_tracker_screen.dart';

import 'helpers.dart';

void main() {
  setUp(resetApp);
  final now = DateTime.now().toUtc();

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(inApp(Builder(
        builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WaitTrackerScreen())),
            child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  TextField aliasField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).last);

  testWidgets('several picks at once, waited silently', (tester) async {
    feed(pointMessage('UAV1', 53.9, 27.5, now, index: 0));
    await show(tester);

    // UAV1 is in the list: shown, but not to be picked
    await tester.tap(find.text('UAV1'));
    await tester.pump();
    expect(find.text('Ждать трекер'), findsNWidgets(2),
        reason: 'the title and the button, nothing picked');

    await tester.tap(find.text('UAV2'));
    await tester.pump();
    expect(find.text('Ждать БЛА 2'), findsOneWidget);
    expect(aliasField(tester).enabled, isTrue, reason: 'one: a name allowed');

    await tester.tap(find.text('UAV3'));
    await tester.tap(find.text('GROUND1'));
    await tester.pump();
    expect(find.text('Ждать 3 трекера'), findsOneWidget);
    expect(find.text('Выбрано: UAV2, UAV3, GROUND1'), findsOneWidget);
    expect(aliasField(tester).enabled, isFalse);

    await tester.tap(find.text('Ждать 3 трекера'));
    await tester.pumpAndSettle();
    expect(find.byType(WaitTrackerScreen), findsNothing);
    expect(
        app.store.waiting.map((w) => w.name.key), ['UAV2', 'UAV3', 'GROUND1']);
    expect(app.store.waiting.every((w) => !w.notify), isTrue,
        reason: 'the switch is off by default');
  });

  testWidgets('one typed name with a name of its own and an alert',
      (tester) async {
    await show(tester);
    await tester.enterText(find.byType(TextField).first, 'uav 4');
    await tester.pump();
    expect(find.text('БЛА 4 UAV4'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Красный самолёт');
    await tester.tap(find.text('Уведомить, когда появится'));
    await tester.pump();
    await tester.tap(find.text('Ждать БЛА 4'));
    await tester.pumpAndSettle();

    expect(app.store.aliasOf('UAV4'), 'Красный самолёт');
    expect(app.store.waiting.single.notify, isTrue);
  });

  testWidgets('a wrong or taken name is explained, nothing to wait',
      (tester) async {
    feed(pointMessage('GROUND2', 53.9, 27.5, now, index: 0));
    await show(tester);

    await tester.enterText(find.byType(TextField).first, 'hello');
    await tester.pump();
    expect(find.textContaining('Не похоже на имя трекера'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'ground 2');
    await tester.pump();
    expect(find.text('Этот трекер уже в списке'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Ждать трекер').last,
        matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
  });
}
