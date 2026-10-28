import 'tracker_point.dart';

/// a parsed message from the tracker
sealed class TrackerMessage {
  const TrackerMessage();
}

/// a position: of another tracker (with &index, stored in the tracker's
/// memory) or of the connected tracker itself (without &index)
class PointMessage extends TrackerMessage {
  const PointMessage(this.point);

  final TrackerPoint point;
}

/// the tracker's memory state; carries the connected tracker's name
class MemoryMessage extends TrackerMessage {
  const MemoryMessage({this.deviceName});

  final String? deviceName;
}

/// old firmware: the tracker's own id
class InfoMessage extends TrackerMessage {
  const InfoMessage({this.id});

  final String? id;
}

/// [message] without the prefix and the terminator: `point&ver=2.3&…`;
/// null for unknown or broken messages
TrackerMessage? parseMessage(String message, {DateTime? receivedAt}) {
  final fields = message.split('&');
  switch (fields.first) {
    case 'point':
    case 'newpoint':
      final point = parsePoint(fields, receivedAt: receivedAt);
      return point == null ? null : PointMessage(point);
    case 'memory':
      return MemoryMessage(deviceName: _value(fields, 'dev_name'));
    case 'info':
      return InfoMessage(id: _value(fields, 'myId'));
  }
  return null;
}

String? _value(List<String> fields, String key) {
  for (final field in fields) {
    final f = field.trim();
    if (f.startsWith('$key=')) return f.substring(key.length + 1);
  }
  return null;
}

/// keys of the point itself; every other key=value is a sensor
const Set<String> _pointKeys = {'id', 'name', 'lat', 'lon', 'timestamp'};

/// null when the name, coordinates or time are missing or broken, and for
/// (0, 0): the tracker sends it when it has no GPS fix
TrackerPoint? parsePoint(List<String> fields, {DateTime? receivedAt}) {
  final values = <String, String>{};
  final sensors = <TrackerSensor>[];

  for (final field in fields.skip(1)) {
    final pair = field.trim().split('=');
    if (pair.length != 2) continue;
    if (_pointKeys.contains(pair[0])) {
      values[pair[0]] = pair[1];
    } else {
      sensors.add(TrackerSensor(name: pair[0], value: pair[1]));
    }
  }

  final name = values['name'];
  final latitude = double.tryParse(values['lat'] ?? '');
  final longitude = double.tryParse(values['lon'] ?? '');
  final time = DateTime.tryParse(values['timestamp'] ?? '');
  if (name == null ||
      name.isEmpty ||
      latitude == null ||
      longitude == null ||
      time == null) {
    return null;
  }
  if (latitude == 0 && longitude == 0) return null;

  return TrackerPoint(
    identifier: name,
    latitude: latitude,
    longitude: longitude,
    time: time,
    sensors: sensors,
    receivedAt: receivedAt,
  );
}
