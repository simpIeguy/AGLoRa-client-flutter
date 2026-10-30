import '../protocol/tracker_name.dart';
import '../protocol/tracker_point.dart';
import 'tracker_status.dart';
import 'tracker_store.dart';

/// one row of the tracker list
class TrackerEntry {
  const TrackerEntry({
    required this.name,
    required this.status,
    this.latest,
    this.alias,
    this.lastHeard,
    this.searchingSatellites = false,
  });

  final TrackerName name;
  final TrackerStatus status;

  /// the last point with a GPS fix; null while waited for or while heard
  /// only without a fix
  final TrackerPoint? latest;
  final String? alias;

  /// the last message of any kind, UTC; null while waited for
  final DateTime? lastHeard;

  /// the last message came without a GPS fix
  final bool searchingSatellites;

  String get key => name.key;
  bool get isUav => name.role == TrackerRole.uav;

  /// the tracker the phone is connected to: the user's own
  bool get isMine => status == TrackerStatus.connected;
}

class TrackerList {
  const TrackerList(this.shown, this.archived, this.hiddenCount);

  /// in the order of the screen
  final List<TrackerEntry> shown;

  /// no data for [trackerArchiveAfter]; the screen folds them
  final List<TrackerEntry> archived;

  /// people and others the user unticked
  final int hiddenCount;
}

/// The order of the list, the most important first:
/// 0. the user's own tracker, always on top;
/// 1. UAVs with a link (green, yellow);
/// 2. UAVs with the link lost (grey), marked so, still among the UAVs;
/// 3. UAVs waited for, no signal yet;
/// 4. people, active ones above;
/// 5. others (names not UAV…/GROUND…);
/// and the archive apart. Inside a group the cards stand as the user
/// dragged them, the rest in the order of appearance, not of the freshest
/// point: a card does not jump when its tracker sends.
///
/// [includeHidden]: for the "who to show" list, with the unticked ones
TrackerList buildTrackerList(TrackerStore store, DateTime now,
    {bool includeHidden = false}) {
  TrackerEntry heard(String identifier, TrackerPoint? point) {
    final lastHeard = store.lastHeard(identifier)!;
    return TrackerEntry(
      name: parseTrackerName(identifier),
      latest: point,
      alias: store.aliasOf(identifier),
      lastHeard: lastHeard,
      searchingSatellites: store.isSearchingSatellites(identifier),
      status: store.statusOf(identifier, now),
    );
  }

  final all = <TrackerEntry>[
    for (final point in store.latestPoints) heard(point.identifier, point),
    for (final identifier in store.trackersWithoutPoints)
      heard(identifier, null),
  ];
  for (final waited in store.waiting) {
    all.add(TrackerEntry(
      name: waited.name,
      alias: store.aliasOf(waited.name.key),
      status: TrackerStatus.waiting,
    ));
  }

  final shown = <TrackerEntry>[];
  final archived = <TrackerEntry>[];
  int hidden = 0;
  for (final entry in all) {
    final heardAt = entry.lastHeard;
    final canHide = !entry.isUav && entry.status != TrackerStatus.connected;
    if (canHide && !includeHidden && store.isHidden(entry.key)) {
      hidden++;
    } else if (heardAt != null &&
        entry.status != TrackerStatus.connected &&
        now.toUtc().difference(heardAt) >= trackerArchiveAfter) {
      archived.add(entry);
    } else {
      shown.add(entry);
    }
  }

  int byFreshness(TrackerEntry a, TrackerEntry b) {
    final ta = a.lastHeard;
    final tb = b.lastHeard;
    if (ta == null || tb == null) return 0;
    return tb.compareTo(ta);
  }

  int placed(TrackerEntry e) => store.orderOf(e.key) ?? 1 << 30;

  int byGroup(TrackerEntry a, TrackerEntry b) {
    final c = _group(a).compareTo(_group(b));
    return c != 0 ? c : placed(a).compareTo(placed(b));
  }

  // a stable sort: entries with no place of their own keep the order they
  // appeared in
  return TrackerList(_stableSorted(shown, byGroup),
      _stableSorted(archived, byFreshness), hidden);
}

int _group(TrackerEntry e) {
  if (e.isMine) return -1;
  final linked = e.status == TrackerStatus.connected ||
      e.status == TrackerStatus.active ||
      e.status == TrackerStatus.fading;
  switch (e.name.role) {
    case TrackerRole.uav:
      if (linked) return 0;
      if (e.status == TrackerStatus.lost) return 1;
      return 2;
    case TrackerRole.ground:
      return linked ? 3 : 4;
    case TrackerRole.other:
      return e.status == TrackerStatus.waiting ? 6 : 5;
  }
}

List<T> _stableSorted<T>(List<T> items, int Function(T, T) compare) {
  final indexed = [for (int i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final item in indexed) item.$2];
}
