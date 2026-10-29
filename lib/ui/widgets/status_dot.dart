import 'package:flutter/widgets.dart';

import '../../data/tracker_status.dart';
import '../theme.dart';

/// The status as a dot, next to the status text. Filled green: the link is
/// there; filled amber: fading; an empty ring: lost or not yet heard. In the
/// night theme green and amber are both red, so "fading" gets a ring around
/// the dot.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status});

  final TrackerStatus status;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final night = p.green == p.amber;
    final BoxDecoration decoration = switch (status) {
      TrackerStatus.connected ||
      TrackerStatus.active =>
        BoxDecoration(color: p.green, shape: BoxShape.circle),
      TrackerStatus.fading when night => BoxDecoration(
          color: p.ink,
          shape: BoxShape.circle,
          border: Border.all(color: p.card, width: 2),
          boxShadow: [BoxShadow(color: p.ink, spreadRadius: 2)]),
      TrackerStatus.fading =>
        BoxDecoration(color: p.amber, shape: BoxShape.circle),
      TrackerStatus.lost || TrackerStatus.waiting => BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: p.muted, width: 2)),
    };
    return Container(
        width: AppSizes.lamp, height: AppSizes.lamp, decoration: decoration);
  }
}
