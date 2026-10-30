import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/services/map_link.dart';
import 'package:tsp_tracker/ui/screens/tracker_screen.dart';

import 'helpers.dart';

void main() {
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

  group('"Открыть в другом приложении" on the tracker screen', () {
    final now = DateTime.now().toUtc();

    Future<void> showLog(WidgetTester tester, UrlOpener open) async {
      resetApp(openUrl: open);
      feed(pointMessage(
          'Tracker2', 53.0, 27.0, now.subtract(const Duration(minutes: 1)),
          index: 0));
      feed(pointMessage('Tracker2', 53.902284, 27.561831, now, index: 1));
      await tester
          .pumpWidget(inApp(const TrackerScreen(identifier: 'Tracker2')));
      await tester.pump();
    }

    testWidgets('opens the newest point', (tester) async {
      Uri? opened;
      await showLog(tester, (uri) async {
        opened ??= uri;
        return true;
      });

      await tester.tap(find.text('Открыть в другом приложении'));
      await tester.pump();

      expect(opened.toString(),
          'geo:53.902284,27.561831?q=53.902284,27.561831(Tracker2)');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('says so when nothing can open the link', (tester) async {
      await showLog(tester, (uri) async => false);

      await tester.tap(find.text('Открыть в другом приложении'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Не удалось открыть карты на этом телефоне'),
          findsOneWidget);
    });

    testWidgets('no button without points', (tester) async {
      resetApp();
      await tester.pumpWidget(inApp(const TrackerScreen(identifier: 'Nobody')));
      expect(find.text('Открыть в другом приложении'), findsNothing);
      expect(find.text('Точек пока нет'), findsOneWidget);
    });
  });
}
