/// Names of the trackers in the firmware (NAME in settings.h): UAV1…UAV9 for
/// UAVs, GROUND1…GROUND9 for people. The role is taken from the start of the
/// name, whatever the letter case; spaces, hyphens and underscores are
/// ignored, and so is anything after the number.
enum TrackerRole { uav, ground, other }

class TrackerName {
  const TrackerName(this.role, this.number, this.raw);

  final TrackerRole role;

  /// null when the name has no number after the role
  final int? number;

  /// the name as the tracker sends it
  final String raw;

  /// one key for "uav1", "UAV 1", "Uav-1": UAV1; other names as they are
  String get key {
    if (role == TrackerRole.other || number == null) return raw;
    return '${_prefixes[role]}$number';
  }

  /// UAV and person names have both a role and a number
  bool get isKnown => role != TrackerRole.other && number != null;
}

const Map<TrackerRole, String> _prefixes = {
  TrackerRole.uav: 'UAV',
  TrackerRole.ground: 'GROUND',
};

final RegExp _separators = RegExp(r'[\s\-_]');
final RegExp _leadingNumber = RegExp(r'^(\d+)');

TrackerName parseTrackerName(String raw) {
  final name = raw.trim();
  final compact = name.replaceAll(_separators, '').toUpperCase();

  for (final entry in _prefixes.entries) {
    if (!compact.startsWith(entry.value)) continue;
    final match =
        _leadingNumber.firstMatch(compact.substring(entry.value.length));
    final number = match == null ? null : int.parse(match.group(1)!);
    return TrackerName(entry.key, number, name);
  }
  return TrackerName(TrackerRole.other, null, name);
}
