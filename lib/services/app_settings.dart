import 'package:flutter/foundation.dart';

import '../data/landmark.dart';
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

  bool _showMyTracker = true;

  /// the user's own tracker on the map: on by default, it can be taken off in
  /// its screen
  bool get showMyTracker => _showMyTracker;

  set showMyTracker(bool value) {
    if (_showMyTracker == value) return;
    _showMyTracker = value;
    notifyListeners();
  }

  /// other trackers the user took off the map (all are on it by default)
  final Set<String> _hiddenOnMap = {};

  /// is this tracker on the map; the user's own one is decided by
  /// [showMyTracker], any other by the user's choice
  bool isOnMap(String key, {required bool mine}) =>
      mine ? _showMyTracker : !_hiddenOnMap.contains(key);

  void setOnMap(String key, bool shown, {required bool mine}) {
    if (mine) {
      showMyTracker = shown;
      return;
    }
    final changed = shown ? _hiddenOnMap.remove(key) : _hiddenOnMap.add(key);
    if (changed) notifyListeners();
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

  final List<Landmark> _landmarks = [];

  /// the points put on the map by coordinates, in the order added
  List<Landmark> get landmarks => List.unmodifiable(_landmarks);

  Landmark addLandmark(String name, double latitude, double longitude) {
    final id = _landmarks.fold<int>(0, (m, l) => l.id > m ? l.id : m) + 1;
    final landmark = Landmark(
        id: id, name: name.trim(), latitude: latitude, longitude: longitude);
    _landmarks.add(landmark);
    notifyListeners();
    return landmark;
  }

  void removeLandmark(int id) {
    final before = _landmarks.length;
    _landmarks.removeWhere((l) => l.id == id);
    if (_landmarks.length != before) notifyListeners();
  }

  /// show or hide one landmark on the map
  void setLandmarkVisible(int id, bool visible) {
    final i = _landmarks.indexWhere((l) => l.id == id);
    if (i < 0 || _landmarks[i].visible == visible) return;
    _landmarks[i] = _landmarks[i].withVisible(visible);
    notifyListeners();
  }

  /// show or hide all the landmarks at once
  void setAllLandmarksVisible(bool visible) {
    for (var i = 0; i < _landmarks.length; i++) {
      _landmarks[i] = _landmarks[i].withVisible(visible);
    }
    notifyListeners();
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
        // a new key: the old "false" was only the old default
        'showMineOnMap': _showMyTracker,
        'hiddenTracks': _hiddenTracks.toList(),
        'hiddenOnMap': _hiddenOnMap.toList(),
        'landmarks': [for (final l in _landmarks) l.toJson()],
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
    final showMine = json['showMineOnMap'];
    if (showMine is bool) _showMyTracker = showMine;
    final hidden = json['hiddenTracks'];
    if (hidden is List) {
      _hiddenTracks
        ..clear()
        ..addAll(hidden.whereType<String>());
    }
    final offMap = json['hiddenOnMap'];
    if (offMap is List) {
      _hiddenOnMap
        ..clear()
        ..addAll(offMap.whereType<String>());
    }
    final landmarks = json['landmarks'];
    if (landmarks is List) {
      _landmarks
        ..clear()
        ..addAll(landmarks.map(Landmark.fromJson).whereType<Landmark>());
    }
    if (json['lastTracker'] case {'id': String id, 'name': String name}) {
      _lastTracker = (id: id, name: name);
    }
    notifyListeners();
  }
}
