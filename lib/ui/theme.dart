import 'package:flutter/material.dart';

import '../data/sensor_lamps.dart';
import '../data/tracker_status.dart';

/// All colors of the app. Screens take colors only from here or from the
/// theme, so the look changes in one place.
abstract final class AppColors {
  static const Color brand = Color(0xFF1565C0);

  static final Color connected = Colors.blue.shade700;
  static final Color active = Colors.green.shade700;
  static final Color fading = Colors.amber.shade400;
  static final Color lost = Colors.grey.shade500;

  /// a tracker that has not sent anything yet
  static final Color waiting = Colors.grey.shade300;

  static const Color onDark = Colors.white;
  static const Color onLight = Colors.black87;

  /// shown under the map while tiles load, instead of a black screen
  static final Color mapBackground = Colors.grey.shade300;
  static const Color mapControl = Colors.white;
  static const Color mapControlIcon = Colors.black87;
  static const Color northNeedle = Colors.red;
  static const Color phoneMarker = Colors.blueAccent;
  static final Color markerShadow = Colors.grey.withValues(alpha: 0.5);
  static final Color mapAttributionBackground =
      Colors.white.withValues(alpha: 0.7);
  static const Color mutedText = Color(0xFF616161);

  /// the full-screen arrow: black saves the battery on AMOLED screens
  static const Color amoledBackground = Colors.black;
  static const Color amoledText = Colors.white;
  static const Color amoledMuted = Color(0xFFB0B0B0);

  /// phone GPS and compass lamps
  static final Color lampGood = Colors.green.shade600;
  static final Color lampFair = Colors.amber.shade600;
  static final Color lampBad = Colors.red.shade600;
  static final Color lampOff = Colors.grey.shade500;

  static Color status(TrackerStatus status) => switch (status) {
        TrackerStatus.connected => connected,
        TrackerStatus.active => active,
        TrackerStatus.fading => fading,
        TrackerStatus.lost => lost,
        TrackerStatus.waiting => waiting,
      };

  static Color lamp(LampLevel level) => switch (level) {
        LampLevel.good => lampGood,
        LampLevel.fair => lampFair,
        LampLevel.bad => lampBad,
        LampLevel.off => lampOff,
      };

  /// black or white, whichever reads better on the background
  static Color readableOn(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? onDark
          : onLight;
}

/// Sizes for use outdoors, in gloves: nothing to tap is smaller than 48 dp.
abstract final class AppSizes {
  static const double minTap = 48;
  static const double gap = 8;
  static const double padding = 12;
  static const double cardRadius = 16;
  static const double cardArrow = 72;
  static const double bigArrow = 260;
  static const double lamp = 12;
  static const double mapAttributionText = 10;
}

/// the theme the user picks in the settings; auto follows the phone
enum AppThemeChoice { auto, light, dark, night }

/// The colors of one theme, as in the design mockups (docs/design). Screens
/// take them with [AppPalette.of].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.card,
    required this.line,
    required this.ink,
    required this.muted,
    required this.green,
    required this.amber,
    required this.onInk,
  });

  final Brightness brightness;
  final Color background;
  final Color card;

  /// borders and separators
  final Color line;

  /// text, the arrow, filled buttons
  final Color ink;

  /// secondary text, the lost status ring
  final Color muted;

  /// "link is there" dot
  final Color green;

  /// "link is fading" dot
  final Color amber;

  /// text on [ink], for filled buttons and the toast
  final Color onInk;

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF4F4F2),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFD9DBD7),
    ink: Color(0xFF14181B),
    muted: Color(0xFF4F575D),
    green: Color(0xFF1A8040),
    amber: Color(0xFFB87400),
    onInk: Color(0xFFFFFFFF),
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0E1012),
    card: Color(0xFF181B1E),
    line: Color(0xFF2C3135),
    ink: Color(0xFFF1F3F4),
    muted: Color(0xFFA9B0B6),
    green: Color(0xFF4ADE80),
    amber: Color(0xFFFBBF24),
    onInk: Color(0xFF0E1012),
  );

  /// red on black: keeps the eyes used to the dark; the statuses differ by
  /// the dot's shape, not by color
  static const AppPalette night = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0A0000),
    card: Color(0xFF160404),
    line: Color(0xFF3A1212),
    ink: Color(0xFFFF5A4D),
    muted: Color(0xFFD04A40),
    green: Color(0xFFFF5A4D),
    amber: Color(0xFFFF5A4D),
    onInk: Color(0xFF0A0000),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  @override
  AppPalette copyWith() => this;

  // themes switch at once, there is nothing to animate
  @override
  AppPalette lerp(AppPalette? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// the light and the dark theme for [MaterialApp] and when to use which
({AppPalette light, AppPalette dark, ThemeMode mode}) themesFor(
        AppThemeChoice choice) =>
    switch (choice) {
      AppThemeChoice.auto => (
          light: AppPalette.light,
          dark: AppPalette.dark,
          mode: ThemeMode.system
        ),
      AppThemeChoice.light => (
          light: AppPalette.light,
          dark: AppPalette.dark,
          mode: ThemeMode.light
        ),
      AppThemeChoice.dark => (
          light: AppPalette.light,
          dark: AppPalette.dark,
          mode: ThemeMode.dark
        ),
      AppThemeChoice.night => (
          light: AppPalette.night,
          dark: AppPalette.night,
          mode: ThemeMode.dark
        ),
    };

/// The three text sizes of the design: large numbers, main text, small
/// text (the full screen uses [AppText.huge] instead of [AppText.large]).
abstract final class AppText {
  static const String sans = 'IBM Plex Sans';

  /// coordinates and technical names (UAV1): digits of equal width
  static const String mono = 'IBM Plex Mono';

  static const double huge = 80;
  static const double large = 32;
  static const double main = 17;
  static const double small = 14;
}

ThemeData buildAppTheme([AppPalette palette = AppPalette.light]) {
  final scheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.ink,
    onPrimary: palette.onInk,
    secondary: palette.ink,
    onSecondary: palette.onInk,
    error: palette.brightness == Brightness.light
        ? const Color(0xFFB3261E)
        : const Color(0xFFF2B8B5),
    onError: palette.onInk,
    surface: palette.background,
    onSurface: palette.ink,
    onSurfaceVariant: palette.muted,
    surfaceContainerLowest: palette.card,
    surfaceContainerLow: palette.card,
    surfaceContainer: palette.card,
    surfaceContainerHigh: palette.card,
    surfaceContainerHighest: palette.card,
    outline: palette.line,
    outlineVariant: palette.line,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: AppText.sans,
    scaffoldBackgroundColor: palette.background,
    extensions: [palette],
    textTheme: const TextTheme(
      // large numbers: distance on the card
      headlineMedium: TextStyle(
          fontSize: AppText.large,
          fontWeight: FontWeight.w700,
          height: 36 / AppText.large,
          fontFeatures: [FontFeature.tabularFigures()]),
      titleMedium: TextStyle(
          fontSize: AppText.main,
          fontWeight: FontWeight.w600,
          height: 24 / AppText.main),
      bodyLarge: TextStyle(fontSize: AppText.main, height: 24 / AppText.main),
      bodyMedium:
          TextStyle(fontSize: AppText.small, height: 20 / AppText.small),
      labelLarge: TextStyle(
          fontSize: AppText.small,
          fontWeight: FontWeight.w600,
          height: 20 / AppText.small),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.ink,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: palette.line,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          minimumSize: const Size(AppSizes.minTap, AppSizes.minTap)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSizes.minTap, AppSizes.minTap)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.minTap, AppSizes.minTap)),
    ),
  );
}
