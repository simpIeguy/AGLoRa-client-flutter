import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/ui/screens/settings_screen.dart';
import 'package:tsp_tracker/ui/widgets/crash_notice.dart';
import 'package:tsp_tracker/util/log.dart';

import 'helpers.dart';

class _Memory implements LogBackend {
  String text = '';

  @override
  Future<String> read() async => text;

  @override
  Future<void> write(String value) async => text = value;
}

void main() {
  test('coordinates and long numbers do not reach the journal', () {
    expect(maskPlaces('point 53.902281, 27.561831'), 'point #, #');
    expect(maskPlaces('X 5975056 Y 5536935'), 'X # Y #');
    expect(maskPlaces('link: point UAV1'), 'link: point UAV1');
    final log = AppLog()..add('skipped "53.90228,27.56183"');
    expect(log.text, isNot(contains('53.9')));
  });

  test('only the last lines are kept', () {
    final log = AppLog(maxLines: 5);
    for (var i = 0; i < 20; i++) {
      log.add('line $i');
    }
    expect(log.length, 5);
    expect(log.text, contains('line 19'));
    expect(log.text, isNot(contains('line 14')));
  });

  test('an error is written at once and marks the next launch', () async {
    final disk = _Memory();
    final first = AppLog();
    await first.start(disk, header: 'v1');
    expect(first.previousRunHadError, isFalse);
    first.add('ble: link connected');
    first.error(StateError('boom'), StackTrace.current, where: 'zone');
    await first.flush();
    expect(disk.text, contains('!! zone: Bad state: boom'));
    expect(disk.text, contains('ble: link connected'));

    final second = AppLog();
    await second.start(disk, header: 'v1');
    expect(second.previousRunHadError, isTrue);
    expect(second.text, contains('== запуск'));
    await second.flush();

    final third = AppLog();
    await third.start(disk, header: 'v1');
    expect(third.previousRunHadError, isFalse,
        reason: 'the error was already told about');
  });

  test('clearing empties the file too', () async {
    final disk = _Memory();
    final log = AppLog();
    await log.start(disk, header: 'v1');
    log.add('something');
    await log.clear();
    expect(log.length, 0);
    expect(disk.text, isEmpty);
  });

  testWidgets('after an error the next launch offers the journal once',
      (tester) async {
    resetApp();
    final log = AppLog()..previousRunHadError = true;
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(inApp(
      const Scaffold(body: Text('экран')),
      messengerKey: messengerKey,
      builder: (context, child) =>
          CrashNotice(messengerKey: messengerKey, log: log, child: child!),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('была ошибка'), findsOneWidget);
    expect(find.text('Сохранить журнал'), findsOneWidget);
    expect(log.previousRunHadError, isFalse);

    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.textContaining('была ошибка'), findsNothing);
  });

  testWidgets('no error before: no banner', (tester) async {
    resetApp();
    final log = AppLog();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(inApp(
      const Scaffold(body: Text('экран')),
      messengerKey: messengerKey,
      builder: (context, child) =>
          CrashNotice(messengerKey: messengerKey, log: log, child: child!),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('была ошибка'), findsNothing);
  });

  testWidgets('the settings can clear the journal', (tester) async {
    resetApp();
    tester.view.physicalSize = const Size(390 * 3, 2100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    AppLog.instance.add('something');
    await tester.pumpWidget(inApp(const SettingsScreen()));
    expect(find.text('Сохранить журнал'), findsOneWidget);
    await tester.tap(find.text('Очистить журнал'));
    await tester.pumpAndSettle();
    expect(find.text('Журнал очищен'), findsOneWidget);
    expect(AppLog.instance.length, 0);
  });
}
