// Pictures of the screens with the real fonts, for comparing with the
// mockups when no emulator is at hand. Not part of the checks:
//   flutter test tool/screenshots_test.dart --update-goldens
// writes build/screenshots/<screen>_<theme>.png.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/scan_list.dart';
import 'package:tsp_tracker/protocol/tracker_name.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/find_devices_screen.dart';
import 'package:tsp_tracker/ui/screens/full_screen_arrow.dart';
import 'package:tsp_tracker/ui/screens/map_screen.dart';
import 'package:tsp_tracker/ui/screens/permissions_screen.dart';
import 'package:tsp_tracker/ui/screens/settings_screen.dart';
import 'package:tsp_tracker/ui/screens/tracker_screen.dart';
import 'package:tsp_tracker/ui/screens/trackers_screen.dart';
import 'package:tsp_tracker/ui/screens/wait_tracker_screen.dart';
import 'package:tsp_tracker/ui/theme.dart';

import '../test/helpers.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont('IBM Plex Sans', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        'assets/fonts/IBMPlexSans-$w.ttf'
    ]);
    await _loadFont('IBM Plex Mono', [
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf'
    ]);
    final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent;
    await _loadFont('MaterialIcons',
        ['${sdk.path}/artifacts/material_fonts/materialicons-regular.otf']);
  });

  // the full screen: the link, the link lost, a poor compass, no phone GPS
  for (final (state, lost, compass, gps) in [
    ('full', false, 15.0, true),
    ('full_lost', true, 15.0, true),
    ('full_compass', false, 45.0, true),
    ('full_nogps', false, 15.0, false),
    ('full_night', false, 15.0, true),
  ]) {
    testWidgets('full screen, $state', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      resetApp(
          positions: gps
              ? Stream.value(PhonePosition(
                  latitude: 53.8945,
                  longitude: 27.5440,
                  accuracy: 6,
                  time: DateTime.now()))
              : null,
          compass: Stream.value(CompassReading(30, accuracy: compass)));
      if (state == 'full_night') app.settings.theme = AppThemeChoice.night;
      final now = DateTime.now().toUtc();
      feed(pointMessage('UAV1', 53.90228, 27.56183,
          now.subtract(Duration(minutes: lost ? 14 : 0, seconds: 12)),
          index: 0));

      await tester.pumpWidget(inApp(const FullScreenArrow(identifier: 'UAV1')));
      await tester.pump();
      await tester.pump();
      await expectLater(find.byType(FullScreenArrow),
          matchesGoldenFile('../build/screenshots/$state.png'));
    });
  }

  for (final theme in [AppThemeChoice.light, AppThemeChoice.dark]) {
    for (final (name, screen) in [
      (
        'scan',
        ScanView<int>(
          scanning: true,
          seconds: 4,
          connected: [
            ConnectedDevice(name: 'GROUND1', ready: true, onOpen: () {}),
          ],
          found: const [
            FoundDevice(name: 'UAV2', rssi: -55, device: 2),
            FoundDevice(name: 'UAV3', rssi: -68, device: 3),
            FoundDevice(name: 'Mi Band 7', rssi: -75, device: 4),
            FoundDevice(name: '', rssi: -90, device: 5),
          ],
          onConnect: (_) {},
          onScan: () {},
          onStop: () {},
        ) as Widget
      ),
      (
        'noperm',
        PermissionsScreen(
            bluetooth: true,
            location: false,
            onAllow: () {},
            onOpenSettings: () {})
      ),
    ]) {
      testWidgets('$name, ${theme.name}', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        resetApp();
        app.settings.theme = theme;
        await tester.pumpWidget(inApp(screen));
        await tester.pump();
        await expectLater(
            find.byWidget(screen),
            matchesGoldenFile(
                '../build/screenshots/${name}_${theme.name}.png'));
      });
    }

    testWidgets('settings, ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1180 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      resetApp();
      app.settings.theme = theme;
      await tester.pumpWidget(inApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      await expectLater(find.byType(SettingsScreen),
          matchesGoldenFile('../build/screenshots/settings_${theme.name}.png'));
    });

    // no tiles here: the grey under them, the rest as in the app
    testWidgets('map, ${theme.name}', (tester) async {
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
      feed(pointMessage(
          'UAV1', 53.90228, 27.56183, now.subtract(const Duration(seconds: 12)),
          index: 0));
      feed(pointMessage(
          'UAV2', 53.91010, 27.53402, now.subtract(const Duration(minutes: 3)),
          index: 1));
      feed(pointMessage(
          'UAV3', 53.92106, 27.57377, now.subtract(const Duration(minutes: 14)),
          index: 2));
      feed(pointMessage('GROUND2', 53.88710, 27.55410,
          now.subtract(const Duration(seconds: 8)),
          index: 3));

      await tester.pumpWidget(inApp(const MapScreen(
          centerLatitude: 53.902, centerLongitude: 27.552, withTiles: false)));
      await tester.pump();
      await tester.pump();
      await expectLater(find.byType(MapScreen),
          matchesGoldenFile('../build/screenshots/map_${theme.name}.png'));
    });

    testWidgets('wait screen, ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      resetApp();
      app.settings.theme = theme;
      final now = DateTime.now().toUtc();
      for (final name in ['UAV1', 'UAV2', 'UAV3', 'GROUND1', 'GROUND2']) {
        feed(pointMessage(name, 53.9, 27.5, now, index: 0));
      }
      await tester.pumpWidget(inApp(const WaitTrackerScreen()));
      await tester.tap(find.text('UAV4'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(WaitTrackerScreen),
          matchesGoldenFile('../build/screenshots/wait_${theme.name}.png'));
    });
  }

  for (final theme
      in AppThemeChoice.values.where((t) => t != AppThemeChoice.auto)) {
    testWidgets('main screen, ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1040 * 3);
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
      feed(pointMessage('GROUND1', 53.8945, 27.5440, now));
      feed(pointMessage(
          'UAV1', 53.90228, 27.56183, now.subtract(const Duration(seconds: 12)),
          index: 0));
      feed(pointMessage(
          'UAV2', 53.88710, 27.51402, now.subtract(const Duration(minutes: 3)),
          index: 1));
      feed(pointMessage(
          'UAV3', 53.95106, 27.54377, now.subtract(const Duration(minutes: 14)),
          index: 2));
      feed(pointMessage('GROUND2', 53.89010, 27.54810,
          now.subtract(const Duration(seconds: 8)),
          index: 3));
      app.store.addWaiting(parseTrackerName('UAV4'));

      await tester
          .pumpWidget(inApp(const TrackersScreen(demoTitle: 'Поиск БЛА')));
      await tester.pump();
      await tester.pump();
      await expectLater(find.byType(TrackersScreen),
          matchesGoldenFile('../build/screenshots/main_${theme.name}.png'));
    });

    testWidgets('tracker screen, ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1120 * 3);
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
      for (int i = 7; i >= 0; i--) {
        feed(pointMessage('UAV1', 53.90228 - i * 0.0004, 27.56183 - i * 0.0011,
            now.subtract(Duration(seconds: 12 + 30 * i)),
            index: 7 - i, alt: 142.3));
      }

      await tester.pumpWidget(inApp(const TrackerScreen(identifier: 'UAV1')));
      await tester.pump();
      await tester.pump();
      await expectLater(find.byType(TrackerScreen),
          matchesGoldenFile('../build/screenshots/tracker_${theme.name}.png'));
    });
  }
}
