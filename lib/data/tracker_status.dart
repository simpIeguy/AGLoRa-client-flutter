/// coordinates younger than this: the tracker is active (green); the
/// default of "Связь пропадает после"
const Duration trackerActiveTimeout = Duration(minutes: 1);

/// coordinates older than this: the tracker is lost (grey), between the
/// two the link is fading (yellow); the default of "Связь потеряна после"
const Duration trackerLostTimeout = Duration(minutes: 5);

/// the choices in the settings (decision 7 in docs/design/resheniya.md)
const List<Duration> fadingAfterChoices = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
];
const List<Duration> lostAfterChoices = [
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 30),
];

/// no data for this long: the tracker goes to the archive
const Duration trackerArchiveAfter = Duration(days: 7);

/// [waiting]: the user waits for the tracker, no signal yet
enum TrackerStatus { connected, active, fading, lost, waiting }

/// [time] is the tracker's GPS time in UTC; [fadingAfter] and [lostAfter]
/// are the user's thresholds
TrackerStatus trackerStatus({
  required DateTime time,
  required bool isConnected,
  required DateTime now,
  Duration fadingAfter = trackerActiveTimeout,
  Duration lostAfter = trackerLostTimeout,
}) {
  if (isConnected) return TrackerStatus.connected;
  final age = now.toUtc().difference(time);
  if (age < fadingAfter) return TrackerStatus.active;
  if (age < lostAfter) return TrackerStatus.fading;
  return TrackerStatus.lost;
}
