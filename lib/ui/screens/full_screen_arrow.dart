import 'package:flutter/material.dart';

import '../../data/direction.dart';
import '../../data/tracker_status.dart';
import '../../protocol/tracker_name.dart';
import '../../protocol/tracker_point.dart';
import '../../services/app_services.dart';
import '../../util/geo.dart';
import '../format.dart';
import '../names.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/coordinates_text.dart';
import '../widgets/copy_coordinates.dart';
import '../widgets/direction_arrow.dart';
import '../widgets/status_dot.dart';
import '../widgets/tracker_card.dart';
import 'tracker_screen.dart';

/// A big arrow to the tracker, as in the Full mockups: white on black
/// (red on black in the night theme), the distance in huge digits, what is
/// wrong with the phone's GPS or compass in a box above the arrow. The
/// screen stays on while it is open. A double tap goes back.
class FullScreenArrow extends StatefulWidget {
  const FullScreenArrow({super.key, required this.identifier});

  final String identifier;

  @override
  State<FullScreenArrow> createState() => _FullScreenArrowState();
}

class _FullScreenArrowState extends State<FullScreenArrow> {
  AppServices? _services;
  bool _keptOn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services != null) return;
    final services = _services = AppScope.of(context);
    if (services.settings.keepScreenOn) {
      _keptOn = true;
      services.keepScreenOn(true);
    }
  }

  @override
  void dispose() {
    if (_keptOn) _services?.keepScreenOn(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final palette = AppPalette.of(context) == AppPalette.night
        ? AppPalette.night
        : AppPalette.full;
    return Theme(
      data: buildAppTheme(palette),
      child: Scaffold(
        backgroundColor: palette.background,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => Navigator.of(context).pop(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  services.store,
                  services.location,
                  services.compass,
                  services.clock,
                ]),
                builder: (context, _) => _content(context, services),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppServices services) {
    final id = widget.identifier;
    final store = services.store;
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final name = parseTrackerName(id);
    final alias = store.aliasOf(id);
    final mine = store.isConnected(id);
    final shownName = displayName(name, alias: alias, mine: mine);
    final point = store.pointsOf(id).firstOrNull;
    final searching = store.isSearchingSatellites(id);

    final heard = store.lastHeard(id);
    final now = services.clock.now;
    final status = store.statusOf(id, now);
    final lost = status == TrackerStatus.lost;
    final age = heard == null ? null : formatAge(now.toUtc().difference(heard));

    final header = [
      TrackerTitle(name: name, alias: alias, mine: mine),
      Row(children: [
        StatusDot(status: status),
        const SizedBox(width: AppSizes.gap),
        Flexible(
            child: Text([statusLabel(status), if (age != null) age].join(' · '),
                style: textTheme.bodyMedium)),
      ]),
      if (lost || searching)
        Padding(
          padding: const EdgeInsets.only(left: AppSizes.lamp + AppSizes.gap),
          child: Text(
              searching
                  ? point == null
                      ? S.searchingSatellites
                      : S.noFixLastGoodPoint
                  : S.toLastKnownPoint,
              style: textTheme.bodyMedium?.copyWith(color: p.muted)),
        ),
    ];

    if (point == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...header,
          const Expanded(child: Center(child: Text(S.noPointsYet))),
          const _ExitHint(),
        ],
      );
    }

    final direction =
        currentDirection(services, point.latitude, point.longitude);
    final bearing = direction.bearing;
    final distance = direction.distance;
    final accuracy = services.location.position?.accuracy;
    final noGps = direction.problem == DirectionProblem.noPhonePosition;
    final details = [
      if (noGps)
        S.gpsAccuracyUnknown
      else ...[
        if (direction.isReliable && bearing != null)
          '${S.azimuth} ${formatBearing(normalizeDegrees(bearing))}'
        else
          S.roughDirection,
        if (accuracy != null) S.gpsAccuracyLine(accuracy.round()),
      ],
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...header,
        if (_problem(direction.problem) case final problem?)
          _ProblemBox(title: problem.title, hint: problem.hint),
        Expanded(
          child: LayoutBuilder(
            // on a short screen the arrow shrinks
            builder: (context, box) => Center(
              child: Semantics(
                label: S.arrowTo(shownName),
                child: DirectionArrow(
                  bearing: bearing,
                  reliable: direction.isReliable,
                  stale: lost,
                  size: box.biggest.shortestSide
                      .clamp(AppSizes.cardArrow, AppSizes.bigArrow),
                  color: p.ink,
                  mutedColor: p.muted,
                ),
              ),
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(distance == null ? '— км' : formatDistance(distance),
              style: TextStyle(
                  fontSize: AppText.huge,
                  fontWeight: FontWeight.w700,
                  height: 84 / AppText.huge,
                  letterSpacing: -0.02 * AppText.huge,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: lost || distance == null ? p.muted : p.ink)),
        ),
        const SizedBox(height: AppSizes.gap),
        Text(details,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: p.muted)),
        const SizedBox(height: 24),
        _Coordinates(
          point: point,
          label: noGps
              ? S.lastPointOf(shownName)
              : lost
                  ? S.lastPoint
                  : null,
        ),
        const _ExitHint(),
      ],
    );
  }

  static ({String title, String? hint})? _problem(DirectionProblem problem) =>
      switch (problem) {
        DirectionProblem.none => null,
        DirectionProblem.noPhonePosition => (
            title: S.noPhoneGps,
            hint: S.noPhoneGpsHint
          ),
        DirectionProblem.noCompass => (
            title: S.noCompass,
            hint: S.noCompassHint
          ),
        DirectionProblem.compassUnreliable => (
            title: S.compassBad,
            hint: S.figureEight
          ),
      };
}

/// "Компас неточный / Помашите телефоном восьмёркой", over the arrow
class _ProblemBox extends StatelessWidget {
  const _ProblemBox({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.screenPadding),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPadding, vertical: AppSizes.padding),
      decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius)),
      child: Row(children: [
        // the amber dot: something to fix, not a tracker's status
        const StatusDot(status: TrackerStatus.fading),
        const SizedBox(width: AppSizes.padding),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              if (hint != null)
                Text(hint!,
                    style: textTheme.bodyMedium?.copyWith(color: p.muted)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// the coordinates with a copy button, under a line; "Последняя точка"
/// above them when the arrow can not lead to the tracker itself
class _Coordinates extends StatelessWidget {
  const _Coordinates({required this.point, this.label});

  final TrackerPoint point;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: EdgeInsets.only(top: label == null ? 0 : AppSizes.gap),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Text(label!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: p.muted)),
          Row(children: [
            Expanded(
              child: GestureDetector(
                // a tap copies, as on the cards
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    copyCoordinates(context, point.latitude, point.longitude),
                onLongPress: () =>
                    showCopyFormats(context, point.latitude, point.longitude),
                child: CoordinatesText(point.latitude, point.longitude),
              ),
            ),
            CopyCoordinatesButton(
              latitude: point.latitude,
              longitude: point.longitude,
              tooltip: S.copyCoordinates,
            ),
          ]),
        ],
      ),
    );
  }
}

class _ExitHint extends StatelessWidget {
  const _ExitHint();

  @override
  Widget build(BuildContext context) => Text(S.exitFullScreen,
      textAlign: TextAlign.center,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppPalette.of(context).muted));
}
