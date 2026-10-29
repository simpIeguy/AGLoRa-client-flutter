import 'package:flutter/foundation.dart';

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
}
