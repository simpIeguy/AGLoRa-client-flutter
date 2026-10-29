import 'package:flutter/foundation.dart';

import '../ui/format.dart';
import '../ui/theme.dart';

/// The user's choices from the settings screen. Kept until the app closes;
/// remembering them between launches comes with the app's memory (TZ-3,
/// block 3).
class AppSettings extends ChangeNotifier {
  AppThemeChoice _theme = AppThemeChoice.auto;

  AppThemeChoice get theme => _theme;

  set theme(AppThemeChoice value) {
    if (_theme == value) return;
    _theme = value;
    notifyListeners();
  }

  CoordinateFormat _coordinates = CoordinateFormat.decimal;

  /// on the screens and when copied; links to map apps are always decimal
  CoordinateFormat get coordinates => _coordinates;

  set coordinates(CoordinateFormat value) {
    if (_coordinates == value) return;
    _coordinates = value;
    notifyListeners();
  }

  bool _keepScreenOn = true;

  /// the full screen keeps the phone's screen on: searching, the phone is in
  /// the hand, not in a pocket
  bool get keepScreenOn => _keepScreenOn;

  set keepScreenOn(bool value) {
    if (_keepScreenOn == value) return;
    _keepScreenOn = value;
    notifyListeners();
  }
}
