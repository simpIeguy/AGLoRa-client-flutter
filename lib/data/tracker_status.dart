/// coordinates younger than this: the tracker is active (green)
const Duration trackerActiveTimeout = Duration(minutes: 1);

/// coordinates older than this: the tracker is lost (grey),
/// between the two timeouts the link is fading (yellow)
const Duration trackerLostTimeout = Duration(minutes: 5);

/// no data for this long: the tracker goes to the archive
const Duration trackerArchiveAfter = Duration(days: 7);

/// [waiting]: the user waits for the tracker, no signal yet
enum TrackerStatus { connected, active, fading, lost, waiting }

/// [time] is the tracker's GPS time in UTC
TrackerStatus trackerStatus({
  required DateTime time,
  required bool isConnected,
  required DateTime now,
}) {
  if (isConnected) return TrackerStatus.connected;
  final age = now.toUtc().difference(time);
  if (age < trackerActiveTimeout) return TrackerStatus.active;
  if (age < trackerLostTimeout) return TrackerStatus.fading;
  return TrackerStatus.lost;
}
