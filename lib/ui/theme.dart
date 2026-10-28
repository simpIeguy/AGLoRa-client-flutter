import 'package:flutter/material.dart';

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

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand);
  return ThemeData(
    colorScheme: scheme,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
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
