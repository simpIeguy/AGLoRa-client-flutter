import 'package:tsp_tracker/screens/screen_tracker_log.dart';
import 'package:tsp_tracker/utils/map_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(resetApp);

  group('links to a map app', () {
    test('geo link: the point and a labeled pin', () {
      expect(geoUri(53.902284, 27.561831, 'Tracker 1').toString(),
          'geo:53.902284,27.561831?q=53.902284,27.561831(Tracker%201)');
    });

    test('web link opens the same point', () {
      final uri = webMapUri(53.902284, 27.561831);
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['query'], '53.902284,27.561831');
    });

    test('the web link is tried only when the map app fails', () async {
      final tried = <Uri>[];
      final ok = await openPointInMaps(53.9, 27.5, 'T', open: (uri) async {
        tried.add(uri);
        return true;
      });
      expect(ok, isTrue);
      expect(tried.map((u) => u.scheme), ['geo']);

      tried.clear();
      final fallback =
          await openPointInMaps(53.9, 27.5, 'T', open: (uri) async {
        tried.add(uri);
        return uri.scheme == 'https';
      });
      expect(fallback, isTrue);
      expect(tried.map((u) => u.scheme), ['geo', 'https']);

      expect(await openPointInMaps(53.9, 27.5, 'T', open: (_) async => false),
          isFalse);
    });
  });

  group('"Открыть в картах" on the log screen', () {
    final now = DateTime.now().toUtc();

    Future<void> showLog(WidgetTester tester, UrlOpener open) async {
      feed(pointMessage(
          'Tracker2', 53.0, 27.0, now.subtract(Duration(minutes: 1)),
          index: 0));
      feed(pointMessage('Tracker2', 53.902284, 27.561831, now, index: 1));
      await tester.pumpWidget(MaterialApp(
          home: TrackerLogScreen(identifier: 'Tracker2', openUrl: open)));
      await tester.pump(Duration(seconds: 1));
    }

    testWidgets('opens the newest point', (tester) async {
      Uri? opened;
      await showLog(tester, (uri) async {
        opened ??= uri;
        return true;
      });

      await tester.tap(find.text('Открыть в картах'));
      await tester.pump();

      expect(opened.toString(),
          'geo:53.902284,27.561831?q=53.902284,27.561831(Tracker2)');
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(SizedBox.shrink());
    });

    testWidgets('says so when nothing can open the link', (tester) async {
      await showLog(tester, (uri) async => false);

      await tester.tap(find.text('Открыть в картах'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Не удалось открыть карты на этом телефоне'),
          findsOneWidget);
      await tester.pumpWidget(SizedBox.shrink());
    });

    testWidgets('no button without points', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: TrackerLogScreen(
              identifier: 'Nobody', openUrl: (_) async => true)));
      await tester.pump(Duration(seconds: 1));
      expect(find.text('Открыть в картах'), findsNothing);
      expect(find.text('Точек пока нет'), findsOneWidget);
      await tester.pumpWidget(SizedBox.shrink());
    });
  });
}
