import '../data/tracker_status.dart';
import '../protocol/tracker_name.dart';
import 'strings.dart';

/// "БЛА 1", "Человек 2", other names as they are; the user's alias first.
/// [mine]: the tracker the phone is connected to is "Вы", not "Человек 1".
String displayName(TrackerName name, {String? alias, bool mine = false}) {
  if (alias != null && alias.isNotEmpty) return alias;
  if (mine) return S.you;
  final role = switch (name.role) {
    TrackerRole.uav => S.uav,
    TrackerRole.ground => S.person,
    TrackerRole.other => null,
  };
  if (role == null) return name.raw;
  return name.number == null ? '$role ${name.raw}' : '$role ${name.number}';
}

String statusLabel(TrackerStatus status) => switch (status) {
      TrackerStatus.connected => S.statusConnected,
      TrackerStatus.active => S.statusActive,
      TrackerStatus.fading => S.statusFading,
      TrackerStatus.lost => S.statusLost,
      TrackerStatus.waiting => S.statusWaiting,
    };
