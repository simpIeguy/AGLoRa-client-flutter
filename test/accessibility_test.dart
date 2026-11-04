// Android accessibility rules from Flutter, over the main screens in every
// theme: tap targets of 48 dp, labels on the buttons, text contrast. Plus a
// large system font: nothing overflows. For use outdoors: the sun, gloves.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/protocol/tracker_name.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/full_screen_arrow.dart';
import 'package:tsp_tracker/ui/screens/map_screen.dart';
import 'package:tsp_tracker/ui/screens/settings_screen.dart';
import 'package:tsp_tracker/ui/screens/tracker_screen.dart';
import 'package:tsp_tracker/ui/screens/trackers_screen.dart';
import 'package:tsp_tracker/ui/screens/wait_tracker_screen.dart';
import 'package:tsp_tracker/ui/theme.dart';

import 'helpers.dart';

/// the screens, each with some trackers: a live one, a fading one, a lost one
final _screens = <String, Widget Function()>{
  'main': () => const TrackersScreen(demoTitle: 'Поиск БЛА'),
  'tracker': () => const TrackerScreen(identifier: 'UAV1'),
  'full screen': () => const FullScreenArrow(identifier: 'UAV3'),
  'settings': () => const SettingsScreen(),
  'wait': () => const WaitTrackerScreen(),
  'map': () => const MapScreen(
      centerLatitude: 53.902, centerLongitude: 27.552, withTiles: false),
};

void _setUp(WidgetTester tester, AppThemeChoice theme) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  resetApp(
      positions: Stream.value(PhonePosition(
          latitude: 53.8945,
          longitude: 27.5440,
          accuracy: 6,
          time: DateTime.now())),
      compass: Stream.value(const CompassReading(30, accuracy: 15)));
  app.settings.theme = theme;
  final now = DateTime.now().toUtc();
  feed(memoryMessage('GROUND1'));
  feed(pointMessage(
      'UAV1', 53.90228, 27.56183, now.subtract(const Duration(seconds: 12)),
      index: 0));
  feed(pointMessage(
      'UAV2', 53.88710, 27.51402, now.subtract(const Duration(minutes: 3)),
      index: 1));
  feed(pointMessage(
      'UAV3', 53.95106, 27.54377, now.subtract(const Duration(minutes: 14)),
      index: 2));
  app.store.addWaiting(parseTrackerName('UAV4'));
}

void main() {
  for (final theme
      in AppThemeChoice.values.where((t) => t != AppThemeChoice.auto)) {
    for (final entry in _screens.entries) {
      testWidgets('${entry.key}, ${theme.name}: tap size, labels, contrast',
          (tester) async {
        final handle = tester.ensureSemantics();
        _setUp(tester, theme);
        await tester.pumpWidget(inApp(entry.value()));
        await tester.pump();
        await tester.pump();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  // the sheet of landmarks, opened over the map, with a landmark in it and
  // coordinates typed
  for (final theme
      in AppThemeChoice.values.where((t) => t != AppThemeChoice.auto)) {
    testWidgets('landmark sheet, ${theme.name}: tap size, labels, contrast',
        (tester) async {
      final handle = tester.ensureSemantics();
      _setUp(tester, theme);
      app.settings.addLandmark('Сбор', 53.903, 27.553);
      await tester.pumpWidget(inApp(_screens['map']!()));
      await tester.pump();
      await tester.tap(find.byTooltip('Метки'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '53.91, 27.57');
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('landmark sheet: system font x2, no overflow', (tester) async {
    _setUp(tester, AppThemeChoice.light);
    app.settings.addLandmark('Сбор', 53.903, 27.553);
    await tester.pumpWidget(inApp(_screens['map']!(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!)));
    await tester.pump();
    await tester.tap(find.byTooltip('Метки'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'X 5975056 Y 5536935');
    await tester.pump();
    final overflow = tester.takeException();
    expect(overflow, isNull,
        reason: overflow is FlutterError
            ? overflow.diagnostics.map((d) => d.toStringDeep()).join()
            : '$overflow');
  });

  // the system font set to the largest size: the text may shrink or wrap,
  // but nothing may overflow (an overflow is an exception in a test)
  for (final scale in [1.5, 2.0]) {
    for (final entry in _screens.entries) {
      testWidgets('${entry.key}: system font x$scale, no overflow',
          (tester) async {
        _setUp(tester, AppThemeChoice.light);
        await tester.pumpWidget(inApp(entry.value(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!)));
        await tester.pump();
        await tester.pump();
        final overflow = tester.takeException();
        expect(overflow, isNull,
            reason: overflow is FlutterError
                ? overflow.diagnostics.map((d) => d.toStringDeep()).join()
                : '$overflow');
      });
    }
  }
}
