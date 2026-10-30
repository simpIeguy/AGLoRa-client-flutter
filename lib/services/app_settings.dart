import 'package:flutter/foundation.dart';

import '../ui/format.dart';
import '../ui/theme.dart';

/// The user's choices from the settings screen and the map. [AppStorage]
/// keeps them between launches.
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

  /// trackers whose track the map does not draw (decision 10: all are
  /// drawn by default)
  final Set<String> _hiddenTracks = {};

  bool isTrackShown(String key) => !_hiddenTracks.contains(key);

  void setTrackShown(String key, bool shown) {
    final changed = shown ? _hiddenTracks.remove(key) : _hiddenTracks.add(key);
    if (changed) notifyListeners();
  }

  /// "Все" in the list of tracks: all drawn or none
  void setTracksShown(Iterable<String> keys, bool shown) {
    var changed = false;
    for (final key in keys) {
      changed |= shown ? _hiddenTracks.remove(key) : _hiddenTracks.add(key);
    }
    if (changed) notifyListeners();
  }

  /// the user's own tracker: the app connects to it again by itself after a
  /// launch; null after "Отключиться"
  ({String id, String name})? _lastTracker;

  ({String id, String name})? get lastTracker => _lastTracker;

  set lastTracker(({String id, String name})? value) {
    if (_lastTracker == value) return;
    _lastTracker = value;
    notifyListeners();
  }

  static const int savedVersion = 1;

  Map<String, Object?> saveState() => {
        'version': savedVersion,
        'theme': _theme.name,
        'coordinates': _coordinates.name,
        'keepScreenOn': _keepScreenOn,
        'hiddenTracks': _hiddenTracks.toList(),
        if (_lastTracker case final t?)
          'lastTracker': {'id': t.id, 'name': t.name},
      };

  /// back from [saveState]; a value that is not understood keeps the default
  void loadState(Object? json) {
    if (json is! Map || json['version'] != savedVersion) return;
    T? pick<T extends Enum>(List<T> values, Object? name) =>
        values.where((v) => v.name == name).firstOrNull;
    _theme = pick(AppThemeChoice.values, json['theme']) ?? _theme;
    _coordinates =
        pick(CoordinateFormat.values, json['coordinates']) ?? _coordinates;
    final keep = json['keepScreenOn'];
    if (keep is bool) _keepScreenOn = keep;
    final hidden = json['hiddenTracks'];
    if (hidden is List) {
      _hiddenTracks
        ..clear()
        ..addAll(hidden.whereType<String>());
    }
    if (json['lastTracker'] case {'id': String id, 'name': String name}) {
      _lastTracker = (id: id, name: name);
    }
    notifyListeners();
  }
}
