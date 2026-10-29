import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/tracker_list.dart';
import '../../data/tracker_status.dart';
import '../../protocol/tracker_name.dart';
import '../../protocol/tracker_point.dart';
import '../../services/app_services.dart';
import '../format.dart';
import '../names.dart';
import '../screens/full_screen_arrow.dart';
import '../screens/map_screen.dart';
import '../screens/tracker_log_screen.dart';
import '../strings.dart';
import '../theme.dart';
import 'direction_arrow.dart';

IconData roleIcon(TrackerRole role) => switch (role) {
      TrackerRole.uav => Icons.flight,
      TrackerRole.ground => Icons.person,
      TrackerRole.other => Icons.gps_fixed,
    };

/// One tracker: the whole card takes its status color, a text label says
/// the same. A tap opens the log.
class TrackerCard extends StatelessWidget {
  const TrackerCard({super.key, required this.entry});

  final TrackerEntry entry;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.status(entry.status);
    final foreground = AppColors.readableOn(background);
    final point = entry.latest;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.gap, vertical: AppSizes.gap / 2),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          onTap: point == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      TrackerLogScreen(identifier: point.identifier))),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(textTheme, foreground),
                    if (entry.status == TrackerStatus.waiting)
                      _waitingRow(context)
                    else if (point == null)
                      _noFixNote(S.searchingSatellites)
                    else ...[
                      if (entry.searchingSatellites)
                        _noFixNote(S.noFixLastGoodPoint),
                      if (entry.status != TrackerStatus.connected)
                        _DirectionRow(point: point, foreground: foreground),
                      _coordinatesRow(context, point, foreground),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(TextTheme textTheme, Color foreground) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(roleIcon(entry.name.role), size: 32),
        const SizedBox(width: AppSizes.gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: displayName(entry.name, alias: entry.alias),
                    style: textTheme.titleLarge?.copyWith(
                        color: foreground, fontWeight: FontWeight.bold)),
                // the technical name, as in the firmware
                TextSpan(
                    text: '  ${entry.name.raw}',
                    style: textTheme.bodySmall?.copyWith(color: foreground)),
              ])),
              Text(statusLabel(entry.status),
                  style: textTheme.titleSmall?.copyWith(
                      color: foreground, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        // no battery: the firmware does not measure it and always sends 100
        if (entry.lastHeard != null) _Age(time: entry.lastHeard!),
      ],
    );
  }

  Widget _noFixNote(String text) => Padding(
        padding: const EdgeInsets.only(top: AppSizes.gap),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget _waitingRow(BuildContext context) {
    final store = AppScope.of(context).store;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        style: TextButton.styleFrom(
            foregroundColor: DefaultTextStyle.of(context).style.color),
        icon: const Icon(Icons.close),
        label: const Text(S.remove),
        onPressed: () => store.removeWaiting(entry.key),
      ),
    );
  }

  Widget _coordinatesRow(
      BuildContext context, TrackerPoint point, Color foreground) {
    final coordinates = formatCoordinates(point.latitude, point.longitude);
    return Row(children: [
      Expanded(
        child: GestureDetector(
          // a long press on the coordinates copies them too
          onLongPress: () =>
              copyCoordinates(context, point.latitude, point.longitude),
          child: Text(coordinates,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontFeatures: [const FontFeature.tabularFigures()])),
        ),
      ),
      IconButton(
        tooltip: S.copyCoordinates,
        icon: const Icon(Icons.copy),
        onPressed: () =>
            copyCoordinates(context, point.latitude, point.longitude),
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MapScreen(
                centerLatitude: point.latitude,
                centerLongitude: point.longitude))),
        icon: const Icon(CupertinoIcons.map_pin_ellipse),
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: foreground),
        ),
        label: const Text(S.map),
      ),
    ]);
  }
}

class _Age extends StatelessWidget {
  const _Age({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final clock = AppScope.of(context).clock;
    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) => Text(
          formatAge(clock.now.toUtc().difference(time)),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: DefaultTextStyle.of(context).style.color)),
    );
  }
}

/// arrow, direction and distance from the phone; double tap or long press
/// on the arrow opens it full screen
class _DirectionRow extends StatelessWidget {
  const _DirectionRow({required this.point, required this.foreground});

  final TrackerPoint point;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final style = Theme.of(context)
        .textTheme
        .headlineSmall
        ?.copyWith(color: foreground, fontWeight: FontWeight.bold);
    final muted = foreground.withValues(alpha: 0.45);

    void openFullScreen() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FullScreenArrow(identifier: point.identifier)));

    return ListenableBuilder(
      listenable: Listenable.merge([services.location, services.compass]),
      builder: (context, _) {
        final direction =
            currentDirection(services, point.latitude, point.longitude);
        final problem = directionProblemText(direction.problem);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.gap),
          child: Row(children: [
            GestureDetector(
              onDoubleTap: openFullScreen,
              onLongPress: openFullScreen,
              child: Semantics(
                label: S.fullScreenHint,
                child: DirectionArrow(
                  bearing: direction.bearing,
                  reliable: direction.isReliable,
                  size: AppSizes.cardArrow,
                  color: foreground,
                  mutedColor: muted,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.padding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (direction.distance != null)
                    Text(formatDistance(direction.distance!), style: style),
                  if (direction.bearing != null)
                    Text('${S.toTracker} ${formatBearing(direction.bearing!)}'),
                  if (problem != null)
                    Text(problem,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}
