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
  });

  final TrackerName name;
  final TrackerStatus status;

  /// null while the tracker is waited for
  final TrackerPoint? latest;
  final String? alias;

  String get key => name.key;
  bool get isUav => name.role == TrackerRole.uav;
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
/// 1. UAVs with a link (connected, green, yellow);
/// 2. UAVs with the link lost (grey), marked so, still among the UAVs;
/// 3. UAVs waited for, no signal yet;
/// 4. people, active ones above;
/// 5. others (names not UAV…/GROUND…);
/// and the archive apart. Inside a group the freshest point goes first.
///
/// [includeHidden]: for the "who to show" list, with the unticked ones
TrackerList buildTrackerList(TrackerStore store, DateTime now,
    {bool includeHidden = false}) {
  final all = <TrackerEntry>[];
  for (final point in store.latestPoints) {
    all.add(TrackerEntry(
      name: parseTrackerName(point.identifier),
      latest: point,
      alias: store.aliasOf(point.identifier),
      status: trackerStatus(
          time: point.time,
          isConnected: store.isConnected(point.identifier),
          now: now),
    ));
  }
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
    final point = entry.latest;
    final canHide = !entry.isUav && entry.status != TrackerStatus.connected;
    if (canHide && !includeHidden && store.isHidden(entry.key)) {
      hidden++;
    } else if (point != null &&
        entry.status != TrackerStatus.connected &&
        now.toUtc().difference(point.time) >= trackerArchiveAfter) {
      archived.add(entry);
    } else {
      shown.add(entry);
    }
  }

  int byFreshness(TrackerEntry a, TrackerEntry b) {
    final ta = a.latest?.time;
    final tb = b.latest?.time;
    if (ta == null || tb == null) return 0;
    return tb.compareTo(ta);
  }

  int compare(TrackerEntry a, TrackerEntry b) {
    final group = _group(a).compareTo(_group(b));
    return group != 0 ? group : byFreshness(a, b);
  }

  // a stable sort: entries of one group with equal times keep their order
  return TrackerList(_stableSorted(shown, compare),
      _stableSorted(archived, byFreshness), hidden);
}

int _group(TrackerEntry e) {
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
