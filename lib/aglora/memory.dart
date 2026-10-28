import 'package:flutter/foundation.dart';

import 'data.dart';

Memory agloraAppMemory = Memory();

/// how many points of one tracker the app keeps for the log screen
const int pointsPerTrackerLimit = 50;

class Memory {
  String myID = '';
  List<AGLORATrackerPoint> memory = [];
  List<AGLORATrackerPoint> trackers = [];

  /// name of the tracker the phone is connected to over BLE
  String? connectedTracker;

  void setIdTo(String? newID) {
    if (newID != null) {
      myID = newID;
    }
  }

  void setConnectedTracker(String? name) {
    if (connectedTracker == name) return;
    connectedTracker = name;
    updateTrackersInUI();
  }

  /// tracker's points, the newest first
  List<AGLORATrackerPoint> pointsOf(String identifier) {
    final points =
        memory.where((point) => point.identifier == identifier).toList();
    points.sort((a, b) => b.time.compareTo(a.time));
    return points;
  }

  /// drop the oldest points of a tracker above the limit
  void _trimPointsOf(String identifier) {
    final points = pointsOf(identifier);
    if (points.length <= pointsPerTrackerLimit) return;
    final extra = points.sublist(pointsPerTrackerLimit).toSet();
    memory.removeWhere((point) => extra.contains(point));
  }

  /// add new point to memory
  void addPoint(AGLORATrackerPoint? newPoint) {
    bool isPointNew = true;
    if (newPoint != null) {
      // save point to memory if it doesn't exist
      memory.forEach((point) {
        final isSameNames = (point.identifier == newPoint.identifier);
        final isSameCoords = (point.latitude == newPoint.latitude) &&
            (point.longitude == newPoint.longitude);
        final isSameTimes = (point.time == newPoint.time);

        // The most reliable way  :-)
        if (isSameNames && isSameCoords && isSameTimes) {
          if (kDebugMode) print('MEMORY: Point already exists');
          isPointNew = false;
        }
      });

      if (isPointNew) {
        memory.add(newPoint);
        _trimPointsOf(newPoint.identifier);

        if (kDebugMode) {
          print('MEMORY: Point has been added. '
              'Total ${memory.length} points');
          print('Name: ${newPoint.identifier}');
          newPoint.sensors?.forEach((sensor) {
            print('${sensor.name}: ${sensor.value}');
          });
        }
      }
    }

    recalculateTrackers();
    updateTrackersInUI();
  }

  /// find fresh tracker's points in the memory
  recalculateTrackers() {
    trackers.clear();

    memory.forEach((point) {
      bool noTrackerYet = true;

      for (var i = 0; i < trackers.length; i++) {
        if (trackers[i].identifier == point.identifier) {
          noTrackerYet = false;
          if (point.time.isAfter(trackers[i].time)) {
            trackers[i] = point;
          }
        }
      }
      if (noTrackerYet) {
        trackers.add(point);
      }
    });
  }

  /// send a new list of trackers to the UI
  void updateTrackersInUI() {
    if (dataStreamController.hasListener) {
      dataStreamController.add(trackers);
      if (kDebugMode) print('MEMORY: ${trackers.length} trackers in memory');
    }
  }

  /// clear all track points
  void eraseAllData() {
    memory.clear();
  }

  /// forget everything: before a demo run and between tests
  void reset() {
    memory.clear();
    trackers.clear();
    connectedTracker = null;
    updateTrackersInUI();
  }
}
