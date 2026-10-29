import 'dart:async';

import 'package:flutter/foundation.dart';

import '../protocol/tracker_name.dart';
import '../protocol/tracker_point.dart';
import 'tracker_status.dart';

/// a tracker the user waits for: shown before its first point
class WaitingTracker {
  const WaitingTracker(this.name, {required this.since, this.notify = true});

  final TrackerName name;
  final DateTime since;

  /// false: waited for silently, no "came on air" alert
  final bool notify;
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

  /// trackers that already had their "came on air" moment
  final Set<String> _onAir = {};

  /// waited trackers whose points so far were only old ones → whether to
  /// alert when a fresh one comes
  final Map<String, bool> _waitedFor = {};

  /// key → the last message without a GPS fix: the name as sent and the
  /// phone's time (UTC), the tracker's own time is cleared in such messages
  final Map<String, ({String identifier, DateTime at})> _noFix = {};

  final DateTime Function() _now;

  /// [now] replaces the phone's clock in tests
  TrackerStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

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

    // with a point it is a tracker in the list, no longer a stub
    _stopWaiting(key);
    _checkOnAir(key, point);
    notifyListeners();
    return true;
  }

  /// The first fresh point is the moment to tell the user. Old points (the
  /// history the tracker sends on connect) do not count: the tracker may
  /// have fallen silent long ago.
  void _checkOnAir(String key, TrackerPoint point) {
    if (_onAir.contains(key)) return;
    if (_now().toUtc().difference(point.time) >= trackerLostTimeout) return;
    _onAir.add(key);
    final waited = _waitedFor.remove(key);
    if (waited != null) {
      // waited silently: no alert, not even as a new UAV
      if (waited) _firstSignals.add(FirstSignal(point, wasWaited: true));
    } else if (_alertNewUavs &&
        parseTrackerName(point.identifier).role == TrackerRole.uav) {
      _firstSignals.add(FirstSignal(point, wasWaited: false));
    }
  }

  /// The tracker is on air but its GPS has no fix: it is alive, its
  /// coordinates are not. Points with a fix stay as they were.
  void heardWithoutFix(String identifier) {
    final key = trackerKey(identifier);
    _noFix[key] = (identifier: identifier, at: _now().toUtc());
    // on air: no longer a stub; the alert waits for the first fix
    _stopWaiting(key);
    notifyListeners();
  }

  void _stopWaiting(String key) {
    final waited = _waiting.remove(key);
    if (waited != null) _waitedFor[key] = waited.notify;
  }

  /// the newest of the last point's GPS time and the last message without
  /// a fix, UTC; null for a tracker never heard
  DateTime? lastHeard(String identifier) {
    final key = trackerKey(identifier);
    final points = _points[key];
    final fix = points == null || points.isEmpty ? null : points.first.time;
    final noFix = _noFix[key]?.at;
    if (fix == null || noFix == null) return fix ?? noFix;
    return noFix.isAfter(fix) ? noFix : fix;
  }

  /// the last message came without a GPS fix: the coordinates shown are the
  /// last good ones (or none yet)
  bool isSearchingSatellites(String identifier) {
    final key = trackerKey(identifier);
    final noFix = _noFix[key]?.at;
    if (noFix == null) return false;
    final points = _points[key];
    return points == null || points.isEmpty || noFix.isAfter(points.first.time);
  }

  /// heard only without a fix so far: names as sent
  List<String> get trackersWithoutPoints => [
        for (final e in _noFix.entries)
          if (_points[e.key]?.isNotEmpty != true) e.value.identifier,
      ];

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
    return _points.containsKey(key) ||
        _waiting.containsKey(key) ||
        _noFix.containsKey(key);
  }

  /// false when the tracker is already in the list or waited for
  /// [notify]: alert when it comes on air (the screen's switch, off there)
  bool addWaiting(TrackerName name,
      {String? alias, DateTime? since, bool notify = true}) {
    if (isKnown(name.key)) return false;
    _waiting[name.key] = WaitingTracker(name,
        since: since ?? DateTime.now().toUtc(), notify: notify);
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

  /// forget one tracker: its points, name and the rest; if it is still on
  /// air it comes back as a new one
  void removeTracker(String identifier) {
    final key = trackerKey(identifier);
    _points.remove(key);
    _aliases.remove(key);
    _waiting.remove(key);
    _hidden.remove(key);
    _onAir.remove(key);
    _waitedFor.remove(key);
    _noFix.remove(key);
    notifyListeners();
  }

  /// the phone's time (UTC) of the last message without a GPS fix
  DateTime? heardWithoutFixAt(String identifier) =>
      _noFix[trackerKey(identifier)]?.at;

  /// forget everything: before a demo run and between tests
  void reset() {
    _points.clear();
    _aliases.clear();
    _waiting.clear();
    _hidden.clear();
    _onAir.clear();
    _waitedFor.clear();
    _noFix.clear();
    _connectedTracker = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _firstSignals.close();
    super.dispose();
  }
}
