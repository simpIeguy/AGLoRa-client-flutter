import 'package:flutter/material.dart';

import '../aglora/data.dart';
import '../aglora/memory.dart';

/// coordinates younger than this: the tracker is active (green)
const Duration trackerActiveTimeout = Duration(minutes: 1);

/// coordinates older than this: the tracker is lost (grey),
/// between the two timeouts the link is fading (yellow)
const Duration trackerLostTimeout = Duration(minutes: 5);

enum TrackerStatus { connected, active, fading, lost }

TrackerStatus trackerStatusOf(AGLORATrackerPoint point) =>
    trackerStatusFor(point.identifier, point.time);

/// [time] is the tracker's GPS time in UTC
TrackerStatus trackerStatusFor(String identifier, DateTime time) {
  if (identifier == agloraAppMemory.connectedTracker) {
    return TrackerStatus.connected;
  }
  final age = DateTime.now().toUtc().difference(time);
  if (age < trackerActiveTimeout) return TrackerStatus.active;
  if (age < trackerLostTimeout) return TrackerStatus.fading;
  return TrackerStatus.lost;
}

Color trackerStatusColor(TrackerStatus status) {
  switch (status) {
    case TrackerStatus.connected:
      return Colors.blue.shade700;
    case TrackerStatus.active:
      return Colors.green.shade700;
    case TrackerStatus.fading:
      return Colors.amber.shade400;
    case TrackerStatus.lost:
      return Colors.grey.shade500;
  }
}

/// black or white, whichever reads better on the background
Color readableTextColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black87;
