import 'tracker_name.dart';

/// one extra value of a point: altitude, satellites, battery…
class TrackerSensor {
  const TrackerSensor({required this.name, required this.value});

  final String name;
  final String value;
}

/// one position of a tracker, as the tracker sent it
class TrackerPoint {
  TrackerPoint({
    required this.identifier,
    required this.latitude,
    required this.longitude,
    required this.time,
    this.sensors = const [],
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  /// the tracker's NAME from its firmware, for example UAV1
  final String identifier;
  final double latitude;
  final double longitude;

  /// GPS time of the fix, UTC
  final DateTime time;

  /// phone's local time when the point came over BLE
  final DateTime receivedAt;

  final List<TrackerSensor> sensors;

  String? sensor(String name) {
    for (final s in sensors) {
      if (s.name == name) return s.value;
    }
    return null;
  }

  /// the same fix: a point resent by the tracker or by another one (mesh)
  bool isSameFixAs(TrackerPoint other) =>
      parseTrackerName(identifier).key ==
          parseTrackerName(other.identifier).key &&
      latitude == other.latitude &&
      longitude == other.longitude &&
      time == other.time;
}
