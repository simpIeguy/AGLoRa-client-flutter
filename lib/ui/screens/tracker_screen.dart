import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/track_export.dart';
import '../../data/tracker_status.dart';
import '../../protocol/tracker_name.dart';
import '../../protocol/tracker_point.dart';
import '../../services/app_services.dart';
import '../../services/map_link.dart';
import '../../services/track_sharing.dart';
import '../../util/geo.dart';
import '../format.dart';
import '../names.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/coordinates_text.dart';
import '../widgets/direction_arrow.dart';
import '../widgets/status_dot.dart';
import '../widgets/tracker_card.dart';
import 'full_screen_arrow.dart';
import 'map_screen.dart';

/// One tracker, as in the Tracker mockup: the arrow and the distance, "Открыть
/// в картах", what the tracker sends (GPS, satellites, altitude, times) and
/// its last points. The name can be changed here, the tracker removed.
class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key, required this.identifier});

  final String identifier;

  /// rows in sight in the points' window; the rest scroll
  static const int shortList = 5;

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  String get _id => widget.identifier;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          // refreshes "N мин назад", the arrow, and picks up new points
          listenable: Listenable.merge([
            services.store,
            services.location,
            services.compass,
            services.clock,
          ]),
          builder: (context, _) => _content(context, services),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppServices services) {
    final store = services.store;
    final name = parseTrackerName(_id);
    final alias = store.aliasOf(_id);
    final points = store.pointsOf(_id);
    final latest = points.firstOrNull;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.gap, AppSizes.gap, AppSizes.gap, 0),
        child: Row(children: [
          IconButton(
            tooltip: S.back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSizes.gap),
          Expanded(
              child: TrackerTitle(
                  name: name, alias: alias, mine: store.isConnected(_id))),
          IconButton(
            tooltip: S.rename,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(context, name, alias),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.gap,
              AppSizes.screenPadding,
              AppSizes.screenPadding * 1.5),
          children: [
            _MainCard(identifier: _id, latest: latest),
            if (latest != null) ...[
              const SizedBox(height: AppSizes.screenPadding),
              // our own map, with this tracker chosen
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.bigButton)),
                icon: const Icon(Icons.map_outlined),
                label: const Text(S.showOnMap),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MapScreen(
                        centerLatitude: latest.latitude,
                        centerLongitude: latest.longitude,
                        chosen: _id))),
              ),
              const SizedBox(height: AppSizes.gap),
              // another map application on the phone
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.bigButton)),
                icon: const Icon(Icons.open_in_new),
                label: const Text(S.openInMaps),
                onPressed: () => _openInMaps(context, latest),
              ),
            ],
            const _SectionTitle(S.trackerState),
            ..._stateRows(context, services, latest),
            if (points.isNotEmpty) ...[
              _SectionTitle(S.allPoints(points.length)),
              // a window of five rows that scrolls by itself, so the
              // screen does not grow with every point
              SizedBox(
                height: _PointRow.height *
                    points.length.clamp(1, TrackerScreen.shortList),
                child: Scrollbar(
                  child: ListView.builder(
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: points.length,
                    itemBuilder: (context, i) =>
                        _PointRow(point: points[i], now: services.clock.now),
                  ),
                ),
              ),
              // the points as a file, for a map program or a spreadsheet
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.gap),
                child: Row(children: [
                  for (final format in TrackFormat.values) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize:
                                const Size.fromHeight(AppSizes.minTap)),
                        icon: const Icon(Icons.ios_share),
                        label: Text(format == TrackFormat.gpx
                            ? S.exportGpx
                            : S.exportCsv),
                        onPressed: () =>
                            _export(context, name, alias, points, format),
                      ),
                    ),
                    if (format != TrackFormat.values.last)
                      const SizedBox(width: AppSizes.gap),
                  ],
                ]),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.all(AppSizes.screenPadding),
                child: Text(S.noPointsYet),
              ),
            const SizedBox(height: AppSizes.screenPadding),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text(S.removeTracker),
                onPressed: () => _remove(context, name, alias),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  /// "GPS трекера", satellites, altitude, when the phone got it and the
  /// tracker's GPS time; a row only for what the tracker sent
  List<Widget> _stateRows(
      BuildContext context, AppServices services, TrackerPoint? latest) {
    final store = services.store;
    final searching = store.isSearchingSatellites(_id);
    final heardAt = store.lastHeard(_id);
    if (heardAt == null) {
      return const [_StateRow(S.trackerGps, S.statusWaiting)];
    }

    final satellites = latest?.sensor('sat');
    final altitude = latest?.sensor('alt');
    // without a fix the point shown is an old one: the phone got the
    // newer message without coordinates
    final received = searching
        ? store.heardWithoutFixAt(_id)?.toLocal()
        : latest?.receivedAt;
    return [
      _StateRow(
        S.trackerGps,
        searching
            ? latest == null
                ? S.searchingSatellites
                : S.noFixLastGoodPoint
            : S.gpsValid,
        dot: searching ? TrackerStatus.lost : TrackerStatus.active,
      ),
      // the count of an old point would mislead while satellites are lost
      if (!searching && satellites != null) _StateRow(S.satellites, satellites),
      if (altitude != null)
        _StateRow(S.altitude, S.metres(altitude.replaceAll('.', ','))),
      if (received != null) _StateRow(S.receivedByPhone, formatClock(received)),
      if (latest != null)
        _StateRow(S.gpsTime, formatClock(latest.time.toLocal())),
    ];
  }

  /// the newest point: where the tracker was last seen
  Future<void> _export(BuildContext context, TrackerName name, String? alias,
      List<TrackerPoint> points, TrackFormat format) async {
    final label = displayName(name, alias: alias);
    try {
      await shareTrack(ExportTrack(label: label, points: points), format,
          fileBase:
              '${name.key}-${DateTime.now().toUtc().toIso8601String().substring(0, 10)}');
    } catch (_) {
      if (context.mounted) showMessage(context, S.cannotExport);
    }
  }

  Future<void> _openInMaps(BuildContext context, TrackerPoint point) async {
    final opened = await openPointInMaps(
        point.latitude, point.longitude, point.identifier,
        open: AppScope.of(context).openUrl);
    if (opened || !context.mounted) return;
    showMessage(context, S.cannotOpenMaps);
  }

  Future<void> _rename(
      BuildContext context, TrackerName name, String? alias) async {
    final store = AppScope.of(context).store;
    final text = await showDialog<String>(
        context: context,
        builder: (_) => _RenameDialog(name: name, alias: alias));
    if (text != null) store.setAlias(_id, text);
  }

  Future<void> _remove(
      BuildContext context, TrackerName name, String? alias) async {
    final store = AppScope.of(context).store;
    final navigator = Navigator.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(S.removeTrackerQuestion(
            displayName(name, alias: alias, mine: store.isConnected(_id)))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(S.cancel)),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(S.delete)),
        ],
      ),
    );
    if (yes != true) return;
    navigator.pop();
    store.removeTracker(_id);
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// copies "53.90228, 27.56183" and says so, with the copied text
Future<void> copyCoordinates(
    BuildContext context, double latitude, double longitude) async {
  final text = formatCoordinates(
      latitude, longitude, AppScope.of(context).settings.coordinates);
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showMessage(context, S.copiedValue(text));
}

/// the big arrow (a tap: the full screen), the status, the distance and the
/// azimuth, the coordinates
class _MainCard extends StatelessWidget {
  const _MainCard({required this.identifier, required this.latest});

  final String identifier;
  final TrackerPoint? latest;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.store;
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final point = latest;

    final heard = store.lastHeard(identifier);
    final now = services.clock.now;
    final status = store.statusOf(identifier, now);
    final lost = status == TrackerStatus.lost;
    final since = heard == null ? null : now.toUtc().difference(heard);
    final direction = point == null
        ? null
        : currentDirection(services, point.latitude, point.longitude);
    final distance = direction?.distance;
    final parts = distance == null ? null : distanceParts(distance);
    final bearing = direction?.bearing;
    final problem =
        direction == null ? null : directionProblemText(direction.problem);

    Widget arrow = DirectionArrow(
      bearing: bearing,
      reliable: direction?.isReliable ?? false,
      stale: lost,
      size: AppSizes.trackerArrow,
      color: p.ink,
      mutedColor: p.muted,
    );
    if (point != null) {
      final name = displayName(parseTrackerName(identifier),
          alias: store.aliasOf(identifier),
          mine: store.isConnected(identifier));
      arrow = Semantics(
        container: true,
        button: true,
        label: S.directionTo(name),
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FullScreenArrow(identifier: point.identifier))),
          child: arrow,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding,
          AppSizes.screenPadding, AppSizes.gap, AppSizes.gap),
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            arrow,
            const SizedBox(width: AppSizes.screenPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    StatusDot(status: status),
                    const SizedBox(width: AppSizes.gap),
                    Flexible(
                        child: Text(statusLabel(status),
                            style: textTheme.labelLarge)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: AppSizes.lamp + AppSizes.gap),
                    child: Text(
                        heardLine(
                            since: since,
                            lost: lost,
                            searching: store.isSearchingSatellites(identifier),
                            hasPoint: point != null),
                        style: textTheme.bodyMedium?.copyWith(color: p.muted)),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: parts?.value ?? '—'),
                      if (parts != null)
                        TextSpan(
                            text: ' ${parts.unit}',
                            style: const TextStyle(
                                fontSize: AppText.small,
                                fontWeight: FontWeight.w600)),
                    ]),
                    style: textTheme.headlineMedium?.copyWith(
                        color: lost || parts == null ? p.muted : p.ink),
                  ),
                  if (bearing != null || problem != null)
                    Text(
                        bearing != null
                            ? '${S.azimuth} ${formatBearing(normalizeDegrees(bearing))}'
                            : problem!,
                        style: textTheme.bodyMedium?.copyWith(color: p.muted)),
                ],
              ),
            ),
          ]),
          if (point != null) CoordinatesRow(point: point),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.fromLTRB(4, AppSizes.screenPadding * 1.5, 4, 0),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: AppPalette.of(context).muted)),
      );
}

/// "Спутники ........ 9"
class _StateRow extends StatelessWidget {
  const _StateRow(this.label, this.value, {this.dot});

  final String label;
  final String value;
  final TrackerStatus? dot;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: AppSizes.gap),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style: textTheme.bodyMedium?.copyWith(color: p.muted))),
        const SizedBox(width: AppSizes.padding),
        // the value on the right, a long one wraps there
        Expanded(
          flex: 3,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (dot != null) ...[
              StatusDot(status: dot!),
              const SizedBox(width: AppSizes.gap),
            ],
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// one point: the coordinates, its GPS time and age, a copy button
class _PointRow extends StatelessWidget {
  const _PointRow({required this.point, required this.now});

  /// at least; the window above is five of these tall
  static const double height = 64;

  final TrackerPoint point;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final time = formatClock(point.time.toLocal());
    void copy() => copyCoordinates(context, point.latitude, point.longitude);
    return Container(
      constraints: const BoxConstraints(minHeight: height),
      padding: const EdgeInsets.only(left: 4),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            // a tap copies, as on the cards
            behavior: HitTestBehavior.opaque,
            onTap: copy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoordinatesText(point.latitude, point.longitude),
                Text('$time · ${formatAge(now.toUtc().difference(point.time))}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: p.muted)),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: S.copyCoordinatesAt(time),
          icon: const Icon(Icons.copy_outlined),
          onPressed: copy,
        ),
      ]),
    );
  }
}

/// the user's name for the tracker; empty brings back the firmware's one
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.name, required this.alias});

  final TrackerName name;
  final String? alias;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _text = TextEditingController(text: widget.alias ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void save() => Navigator.of(context).pop(_text.text);
    return AlertDialog(
      title: const Text(S.trackerTitle),
      content: TextField(
        controller: _text,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: displayName(widget.name),
          helperText: S.renameHint(widget.name.raw),
          helperMaxLines: 2,
        ),
        onSubmitted: (_) => save(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(S.cancel)),
        TextButton(onPressed: save, child: const Text(S.save)),
      ],
    );
  }
}
