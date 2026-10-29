import '../protocol/tracker_name.dart';

/// A Bluetooth device the scan found, as the list needs it.
class FoundDevice<T> {
  const FoundDevice(
      {required this.name, required this.rssi, required this.device});

  /// as the device calls itself, may be empty
  final String name;

  /// dBm, the closer to 0 the stronger
  final int rssi;

  /// what to connect to
  final T device;

  /// GROUND1, UAV2: one of ours (decision 11)
  bool get isOurs => parseTrackerName(name).isKnown;
}

/// 1 to 4 bars
int signalBars(int rssi) {
  if (rssi >= -60) return 4;
  if (rssi >= -70) return 3;
  if (rssi >= -80) return 2;
  return 1;
}

/// our trackers first, the strongest signal first in each part
({List<FoundDevice<T>> ours, List<FoundDevice<T>> others}) splitFound<T>(
    Iterable<FoundDevice<T>> found) {
  final sorted = found.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  return (
    ours: [
      for (final d in sorted)
        if (d.isOurs) d
    ],
    others: [
      for (final d in sorted)
        if (!d.isOurs) d
    ],
  );
}
