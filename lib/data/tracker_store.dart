import 'dart:async';

import 'package:flutter/foundation.dart';

import '../protocol/tracker_name.dart';
import '../protocol/tracker_point.dart';

/// a tracker the user waits for: shown before its first point
class WaitingTracker {
  const WaitingTracker(this.name, {required this.since});

  final TrackerName name;
  final DateTime since;
}

/// the first point of a tracker: the app tells the user once
class FirstSignal {
  const FirstSignal(this.point, {required this.wasWaited});

  final TrackerPoint point;

  /// true for a tracker from the waiting list, false for a new UAV
  final bool wasWaited;
}

/// The one place that knows the trackers: their points, names, the waiting
/// list and who is hidden. Screens listen to it and redraw on changes.
///
/// Trackers are keyed by [trackerKey]: "uav1", "UAV 1" and "Uav-1" are one
/// tracker UAV1.
class TrackerStore extends ChangeNotifier {
  /// how many points of one tracker the app keeps for the log screen
  static const int pointsPerTrackerLimit = 50;

  /// key → points, the newest first; trackers in the order first seen
  final Map<String, List<TrackerPoint>> _points = {};

  /// key → the user's own name for the tracker
  final Map<String, String> _aliases = {};

  final Map<String, WaitingTracker> _waiting = {};
  final Set<String> _hidden = {};

  /// trackers the app has ever had a point from
  final Set<String> _seen = {};

  final _firstSignals = StreamController<FirstSignal>.broadcast();

  String? _connectedTracker;
  bool _alertNewUavs = true;

  static String trackerKey(String identifier) =>
      parseTrackerName(identifier).key;

  /// name of the tracker the phone is connected to over BLE
  String? get connectedTracker => _connectedTracker;

  bool isConnected(String identifier) =>
      _connectedTracker != null &&
      trackerKey(_connectedTracker!) == trackerKey(identifier);

  void setConnectedTracker(String? name) {
    if (_connectedTracker == name) return;
    _connectedTracker = name;
    notifyListeners();
  }

  /// the first point of a waited tracker or of a new UAV
  Stream<FirstSignal> get firstSignals => _firstSignals.stream;

  /// a new UAV alerts even if nobody waited for it; on by default
  bool get alertNewUavs => _alertNewUavs;

  set alertNewUavs(bool value) {
    if (_alertNewUavs == value) return;
    _alertNewUavs = value;
    notifyListeners();
  }

  /// false when the same fix is already stored (resent by the tracker)
  bool addPoint(TrackerPoint point) {
    final key = trackerKey(point.identifier);
    final points = _points.putIfAbsent(key, () => []);
    if (points.any(point.isSameFixAs)) return false;

    var at = points.indexWhere((p) => p.time.isBefore(point.time));
    if (at < 0) at = points.length;
    points.insert(at, point);
    if (points.length > pointsPerTrackerLimit) {
      points.removeRange(pointsPerTrackerLimit, points.length);
    }

    if (_seen.add(key)) _onFirstPoint(key, point);
    notifyListeners();
    return true;
  }

  void _onFirstPoint(String key, TrackerPoint point) {
    if (_waiting.remove(key) != null) {
      _firstSignals.add(FirstSignal(point, wasWaited: true));
    } else if (_alertNewUavs &&
        parseTrackerName(point.identifier).role == TrackerRole.uav) {
      _firstSignals.add(FirstSignal(point, wasWaited: false));
    }
  }

  /// tracker's points, the newest first
  List<TrackerPoint> pointsOf(String identifier) => List.unmodifiable(
      _points[trackerKey(identifier)] ?? const <TrackerPoint>[]);

  /// the newest point of every tracker
  List<TrackerPoint> get latestPoints => [
        for (final points in _points.values)
          if (points.isNotEmpty) points.first,
      ];

  int get pointCount =>
      _points.values.fold(0, (sum, points) => sum + points.length);

  // names

  String? aliasOf(String identifier) => _aliases[trackerKey(identifier)];

  void setAlias(String identifier, String? alias) {
    final key = trackerKey(identifier);
    final text = alias?.trim() ?? '';
    if (text.isEmpty) {
      if (_aliases.remove(key) == null) return;
    } else {
      if (_aliases[key] == text) return;
      _aliases[key] = text;
    }
    notifyListeners();
  }

  // waiting list

  List<WaitingTracker> get waiting => List.unmodifiable(_waiting.values);

  /// a tracker that already sent points is not waited for
  bool isKnown(String identifier) {
    final key = trackerKey(identifier);
    return _points.containsKey(key) || _waiting.containsKey(key);
  }

  /// false when the tracker is already in the list or waited for
  bool addWaiting(TrackerName name, {String? alias, DateTime? since}) {
    if (isKnown(name.key)) return false;
    _waiting[name.key] =
        WaitingTracker(name, since: since ?? DateTime.now().toUtc());
    if (alias != null && alias.trim().isNotEmpty) {
      _aliases[name.key] = alias.trim();
    }
    notifyListeners();
    return true;
  }

  void removeWaiting(String identifier) {
    if (_waiting.remove(trackerKey(identifier)) != null) notifyListeners();
  }

  // who is shown

  bool isHidden(String identifier) => _hidden.contains(trackerKey(identifier));

  /// UAVs and the connected tracker can not be hidden: the list makes sure
  void setHidden(String identifier, bool hidden) {
    final key = trackerKey(identifier);
    final changed = hidden ? _hidden.add(key) : _hidden.remove(key);
    if (changed) notifyListeners();
  }

  /// forget everything: before a demo run and between tests
  void reset() {
    _points.clear();
    _aliases.clear();
    _waiting.clear();
    _hidden.clear();
    _seen.clear();
    _connectedTracker = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _firstSignals.close();
    super.dispose();
  }
}
