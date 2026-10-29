// Pictures of the screens with the real fonts, for comparing with the
// mockups when no emulator is at hand. Not part of the checks:
//   flutter test tool/screenshots_test.dart --update-goldens
// writes build/screenshots/<screen>_<theme>.png.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/protocol/tracker_name.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/trackers_screen.dart';
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
  }
}
