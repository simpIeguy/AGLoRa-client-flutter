import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/services/app_settings.dart';
import 'package:tsp_tracker/ui/theme.dart';

void main() {
  test('auto follows the phone, night is red in both', () {
    expect(themesFor(AppThemeChoice.auto).mode, ThemeMode.system);
    expect(themesFor(AppThemeChoice.light).mode, ThemeMode.light);
    expect(themesFor(AppThemeChoice.dark).mode, ThemeMode.dark);
    final night = themesFor(AppThemeChoice.night);
    expect(night.light, AppPalette.night);
    expect(night.dark, AppPalette.night);
  });

  test('the colors of the mockups', () {
    expect(AppPalette.light.background, const Color(0xFFF4F4F2));
    expect(AppPalette.dark.green, const Color(0xFF4ADE80));
    expect(AppPalette.night.ink, const Color(0xFFFF5A4D));
    // night: no green or amber, the dot's shape tells the status
    expect(AppPalette.night.green, AppPalette.night.ink);
    expect(AppPalette.night.amber, AppPalette.night.ink);
  });

  test('the default is auto, a change is announced once', () {
    final settings = AppSettings();
    var changes = 0;
    settings.addListener(() => changes++);
    expect(settings.theme, AppThemeChoice.auto);
    settings.theme = AppThemeChoice.night;
    settings.theme = AppThemeChoice.night;
    expect(changes, 1);
  });

  testWidgets('screens get the palette of the theme', (tester) async {
    late AppPalette palette;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(AppPalette.night),
      home: Builder(builder: (context) {
        palette = AppPalette.of(context);
        return const SizedBox();
      }),
    ));
    expect(palette, AppPalette.night);
  });
}
