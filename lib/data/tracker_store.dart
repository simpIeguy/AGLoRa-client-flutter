import 'package:flutter/foundation.dart';

import '../protocol/tracker_point.dart';

/// The one place that knows the trackers: their points and which one the
/// phone is connected to. Screens listen to it and redraw on changes.
class TrackerStore extends ChangeNotifier {
  /// how many points of one tracker the app keeps for the log screen
  static const int pointsPerTrackerLimit = 50;

  /// tracker → its points, the newest first; trackers in the order they
  /// were first seen
  final Map<String, List<TrackerPoint>> _points = {};

  String? _connectedTracker;

  /// name of the tracker the phone is connected to over BLE
  String? get connectedTracker => _connectedTracker;

  void setConnectedTracker(String? name) {
    if (_connectedTracker == name) return;
    _connectedTracker = name;
    notifyListeners();
  }

  /// false when the same fix is already stored (resent by the tracker)
  bool addPoint(TrackerPoint point) {
    final points = _points.putIfAbsent(point.identifier, () => []);
    if (points.any(point.isSameFixAs)) return false;

    var at = points.indexWhere((p) => p.time.isBefore(point.time));
    if (at < 0) at = points.length;
    points.insert(at, point);
    if (points.length > pointsPerTrackerLimit) {
      points.removeRange(pointsPerTrackerLimit, points.length);
    }
    notifyListeners();
    return true;
  }

  /// tracker's points, the newest first
  List<TrackerPoint> pointsOf(String identifier) =>
      List.unmodifiable(_points[identifier] ?? const <TrackerPoint>[]);

  /// the newest point of every tracker
  List<TrackerPoint> get latestPoints => [
        for (final points in _points.values)
          if (points.isNotEmpty) points.first,
      ];

  int get pointCount =>
      _points.values.fold(0, (sum, points) => sum + points.length);

  /// forget everything: before a demo run and between tests
  void reset() {
    _points.clear();
    _connectedTracker = null;
    notifyListeners();
  }
}
