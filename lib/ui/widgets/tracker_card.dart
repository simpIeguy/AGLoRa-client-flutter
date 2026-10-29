import 'package:flutter/material.dart';

import '../../data/direction.dart';
import '../../data/tracker_list.dart';
import '../../data/tracker_status.dart';
import '../../protocol/tracker_name.dart';
import '../../protocol/tracker_point.dart';
import '../../services/app_services.dart';
import '../format.dart';
import '../names.dart';
import '../screens/full_screen_arrow.dart';
import '../screens/tracker_log_screen.dart';
import '../strings.dart';
import '../theme.dart';
import 'direction_arrow.dart';
import 'status_dot.dart';

IconData roleIcon(TrackerRole role) => switch (role) {
      TrackerRole.uav => Icons.flight,
      TrackerRole.ground => Icons.person,
      TrackerRole.other => Icons.gps_fixed,
    };

/// One tracker, as in the Main mockup: the arrow, the name, the status dot
/// and text, the distance in large digits; the coordinates below with a copy
/// button. The card itself is neutral: the dot and the text tell the status.
/// A tap opens the tracker's screen, a long press on the arrow the full
/// screen.
class TrackerCard extends StatelessWidget {
  const TrackerCard({super.key, required this.entry});

  final TrackerEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.status == TrackerStatus.waiting) {
      return _WaitingStub(entry: entry);
    }
    final p = AppPalette.of(context);
    final point = entry.latest;
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: point == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    TrackerLogScreen(identifier: point.identifier))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding,
              AppSizes.padding, AppSizes.gap, AppSizes.gap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopRow(entry: entry),
              if (point != null) _CoordinatesRow(point: point),
            ],
          ),
        ),
      ),
    );
  }
}

/// "БЛА 1 UAV1": the name and, smaller, the name in the firmware
class TrackerTitle extends StatelessWidget {
  const TrackerTitle({super.key, required this.name, this.alias});

  final TrackerName name;
  final String? alias;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: displayName(name, alias: alias)),
        TextSpan(
            text: ' ${name.raw}',
            style: TextStyle(
                fontFamily: AppText.mono,
                fontSize: AppText.small,
                fontWeight: FontWeight.w500,
                color: p.muted)),
      ]),
      style: Theme.of(context).textTheme.titleMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.entry});

  final TrackerEntry entry;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final lost = entry.status == TrackerStatus.lost;
    return ListenableBuilder(
      listenable: Listenable.merge(
          [services.location, services.compass, services.clock]),
      builder: (context, _) {
        final point = entry.latest;
        final direction = point == null
            ? null
            : currentDirection(services, point.latitude, point.longitude);
        final heard = entry.lastHeard;
        final since =
            heard == null ? null : services.clock.now.toUtc().difference(heard);
        final age = since == null ? '' : formatAge(since);
        final distance = direction?.distance;
        final parts = distance == null ? null : distanceParts(distance);

        return Row(children: [
          _Arrow(entry: entry, direction: direction),
          const SizedBox(width: AppSizes.padding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrackerTitle(name: entry.name, alias: entry.alias),
                Row(children: [
                  StatusDot(status: entry.status),
                  const SizedBox(width: AppSizes.gap),
                  Flexible(
                      child: Text(statusLabel(entry.status),
                          style: textTheme.labelLarge)),
                ]),
                Padding(
                  // under the status text, past the dot
                  padding:
                      const EdgeInsets.only(left: AppSizes.lamp + AppSizes.gap),
                  child: Text(
                      entry.searchingSatellites
                          ? '$age · ${point == null ? S.searchingSatellites : S.noFixLastGoodPoint}'
                          : lost && since != null
                              // "14 мин, последняя точка", as in the mockup
                              ? S.lostAge(formatDuration(since))
                              : age,
                      style: textTheme.bodyMedium?.copyWith(color: p.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.gap),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: parts?.value ?? '—'),
              if (parts != null)
                TextSpan(
                    text: ' ${parts.unit}',
                    style: const TextStyle(
                        fontSize: AppText.small, fontWeight: FontWeight.w600)),
            ]),
            style: textTheme.headlineMedium
                ?.copyWith(color: lost || parts == null ? p.muted : p.ink),
          ),
        ]);
      },
    );
  }
}

/// the arrow; a long press (or a double tap) opens the full screen
class _Arrow extends StatelessWidget {
  const _Arrow({required this.entry, required this.direction});

  final TrackerEntry entry;
  final Direction? direction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final point = entry.latest;
    final d = direction;
    final arrow = DirectionArrow(
      bearing: d?.bearing,
      reliable: d?.isReliable ?? false,
      stale: entry.status == TrackerStatus.lost,
      size: AppSizes.cardArrow,
      color: p.ink,
      mutedColor: p.muted,
    );
    if (point == null) return arrow;
    void open() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FullScreenArrow(identifier: point.identifier)));
    return GestureDetector(
      onLongPress: open,
      onDoubleTap: open,
      child: Semantics(label: S.fullScreenHint, child: arrow),
    );
  }
}

class _CoordinatesRow extends StatelessWidget {
  const _CoordinatesRow({required this.point});

  final TrackerPoint point;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    void copy() => copyCoordinates(context, point.latitude, point.longitude);
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.gap),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            // a long press on the coordinates copies them too
            onLongPress: copy,
            child: Text(formatCoordinates(point.latitude, point.longitude),
                style: const TextStyle(
                    fontFamily: AppText.mono,
                    fontSize: AppText.main,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ),
        IconButton(
          tooltip: S.copyCoordinates,
          icon: const Icon(Icons.copy_outlined),
          onPressed: copy,
        ),
      ]),
    );
  }
}

/// a tracker waited for: a dashed frame, "Ждём первый сигнал", a cross
class _WaitingStub extends StatelessWidget {
  const _WaitingStub({required this.entry});

  final TrackerEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final name = displayName(entry.name, alias: entry.alias);
    return CustomPaint(
      painter: _DashedFrame(p.muted),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.only(
              left: AppSizes.screenPadding, right: AppSizes.gap),
          child: Row(children: [
            const StatusDot(status: TrackerStatus.waiting),
            const SizedBox(width: AppSizes.padding),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrackerTitle(name: entry.name, alias: entry.alias),
                  Text(S.statusWaiting,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: p.muted)),
                ],
              ),
            ),
            IconButton(
              tooltip: S.removeWaiting(name),
              icon: const Icon(Icons.close),
              onPressed: () =>
                  AppScope.of(context).store.removeWaiting(entry.key),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DashedFrame extends CustomPainter {
  _DashedFrame(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(AppSizes.cardRadius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.outline;
    const dash = 6.0, gap = 4.0;
    for (final metric in frame.computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFrame old) => old.color != color;
}
