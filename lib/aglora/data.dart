import 'dart:async';

class AGLoRaSensor {
  AGLoRaSensor({required this.name, required this.value});

  String name;
  String value;
}

class AGLORATrackerPoint {
  AGLORATrackerPoint(
      {required this.identifier,
      required this.latitude,
      required this.longitude,
      required this.time,
      this.sensors,
      DateTime? receivedAt})
      : receivedAt = receivedAt ?? DateTime.now();

  String identifier;
  double latitude;
  double longitude;
  DateTime time; // GPS time of the fix, UTC

  /// phone's local time when the point came over BLE
  DateTime receivedAt;

  List<AGLoRaSensor>? sensors;

  String? sensor(String name) {
    for (final s in sensors ?? <AGLoRaSensor>[]) {
      if (s.name == name) return s.value;
    }
    return null;
  }
}

var dataStreamController =
    StreamController<List<AGLORATrackerPoint>>.broadcast();

Stream<List<AGLORATrackerPoint>> get trackersListStream =>
    dataStreamController.stream;

const String packagePrefix = 'AGLoRa-';
const String packagePostfix = '|';

const requestAllTrackers = 'all';
