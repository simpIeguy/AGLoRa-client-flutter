import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../data/tracker_list.dart';
import '../../data/tracker_status.dart';
import '../../data/tracker_store.dart';
import '../../services/app_services.dart';
import '../../util/geo.dart';
import '../names.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/ask_location.dart';
import '../widgets/status_dot.dart';
import '../widgets/tracker_card.dart';
import 'map/map_layers.dart';
import 'map/map_markers.dart';
import 'tracker_screen.dart';

/// degrees of two-finger twist before the map starts to rotate
const double mapRotationThreshold = 30;

/// 0..1, smaller is smoother but slower to follow the phone's compass
const double compassSmoothing = 0.15;

/// The map, as in the Map mockup: the trackers as dots with labels, the
/// phone with a cone where it points, a line with the distance to the chosen
/// tracker. Below: the trackers to choose from and the chosen one's card.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.centerLatitude,
    required this.centerLongitude,
    this.chosen,
    this.withTiles = true,
  });

  final double centerLatitude;
  final double centerLongitude;

  /// the tracker to show first; the most important one when null
  final String? chosen;

  /// false in tests and screen pictures: no tiles from the internet
  final bool withTiles;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  MapLayerType _layerType = MapLayerType.hybrid;

  double _rotation = 0; // degrees, as the map reports it
  bool _followCompass = false;
  double? _smoothedHeading;

  /// the key of the chosen tracker
  late String? _chosen =
      widget.chosen == null ? null : TrackerStore.trackerKey(widget.chosen!);

  StreamSubscription<MapEvent>? _mapEventSubscription;

  /// the map keeps the chosen tracker in the centre while its points come
  bool _followTracker = false;

  /// the point the map was last moved to while following
  (String, DateTime)? _followedPoint;

  /// the track layers are built again only when [_tracksSignature] changes:
  /// not on every turn of the compass
  String? _tracksSignature;
  List<Widget> _tracksLayers = const [];

  late final AppServices _services = AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _mapEventSubscription = _mapController.mapEventStream.listen((event) {
      // a finger moved the map: it is no longer kept on the tracker
      if (_followTracker &&
          event is MapEventMove &&
          const {
            MapEventSource.dragStart,
            MapEventSource.onDrag,
            MapEventSource.flingAnimationController,
          }.contains(event.source)) {
        setState(() => _followTracker = false);
      }
      if (event is! MapEventRotate) return;
      // a finger turned the map: leave the compass mode
      if (_followCompass && event.source != MapEventSource.mapController) {
        _stopFollowingCompass();
      }
      setState(() => _rotation = _mapController.rotation);
    });
  }

  @override
  void dispose() {
    _mapEventSubscription?.cancel();
    if (_followCompass) _services.compass.removeListener(_onHeading);
    _mapController.dispose();
    super.dispose();
  }

  bool get _isNorthUp =>
      (_rotation % 360).abs() < 0.5 || (_rotation % 360 - 360).abs() < 0.5;

  void _onCompassButton() {
    if (_followCompass) {
      _stopFollowingCompass();
      _mapController.rotate(0);
    } else if (!_isNorthUp) {
      _mapController.rotate(0);
    } else {
      _startFollowingCompass();
    }
  }

  void _onHeading() {
    final heading = _services.compass.reading?.heading;
    if (heading == null || !heading.isFinite) return;
    final previous = _smoothedHeading;
    if (previous == null) {
      _smoothedHeading = heading;
    } else {
      // shortest way around the circle, so 359° → 1° does not spin the map
      final delta = (heading - previous + 540) % 360 - 180;
      if (delta.abs() < 0.3) return;
      _smoothedHeading = (previous + delta * compassSmoothing) % 360;
    }
    // the top of the screen points where the phone points
    _mapController.rotate(-_smoothedHeading!);
  }

  void _startFollowingCompass() {
    _smoothedHeading = null;
    _services.compass.addListener(_onHeading);
    setState(() => _followCompass = true);
  }

  void _stopFollowingCompass() {
    _services.compass.removeListener(_onHeading);
    setState(() => _followCompass = false);
  }

  void _whereAmI(BuildContext context) {
    final phone = _services.location.position;
    if (phone == null) {
      // location off: offer Android's settings, else just say there is no fix
      askToEnableLocation(context, _services.location).then((asked) {
        if (!asked && context.mounted) showMessage(context, S.noPhonePosition);
      });
      return;
    }
    _mapController.move(
        LatLng(phone.latitude, phone.longitude), _mapController.zoom);
  }

  /// a chip or a dot: this tracker now, the map goes to it
  void _choose(TrackerEntry entry) {
    setState(() => _chosen = entry.key);
    final point = entry.latest!;
    _mapController.move(
        LatLng(point.latitude, point.longitude), _mapController.zoom);
  }

  void _toggleFollowTracker() {
    setState(() {
      _followTracker = !_followTracker;
      _followedPoint = null;
    });
  }

  /// while following: to the chosen tracker's newest point, once per point
  void _followChosen(TrackerEntry? chosen) {
    final point = chosen?.latest;
    if (!_followTracker || chosen == null || point == null) return;
    final moved = (chosen.key, point.time);
    if (moved == _followedPoint) return;
    _followedPoint = moved;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_followTracker) return;
      _mapController.move(
          LatLng(point.latitude, point.longitude), _mapController.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mapBackground,
      body: ListenableBuilder(
        // new points, colors by timer, the phone moving and turning
        listenable: Listenable.merge([
          _services.store,
          _services.clock,
          _services.location,
          _services.compass,
          // the tracks ticked in "След"
          _services.settings,
        ]),
        builder: (context, _) {
          final now = _services.clock.now;
          // as on the main screen: the hidden ones are not on the map either
          final entries = [
            for (final e in buildTrackerList(_services.store, now).shown)
              if (e.latest != null) e
          ];
          final chosen = entries.where((e) => e.key == _chosen).firstOrNull ??
              entries.firstOrNull;
          _followChosen(chosen);
          return Stack(children: [
            _map(context, entries, chosen, now),
            SafeArea(child: _controls(context, entries, chosen)),
          ]);
        },
      ),
    );
  }

  Widget _map(BuildContext context, List<TrackerEntry> entries,
      TrackerEntry? chosen, DateTime now) {
    final phone = _services.location.position;
    final phoneAt =
        phone == null ? null : LatLng(phone.latitude, phone.longitude);
    final target = chosen?.latest;
    final targetAt =
        target == null ? null : LatLng(target.latitude, target.longitude);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: LatLng(widget.centerLatitude, widget.centerLongitude),
        zoom: 13.0,
        minZoom: mapMinZoom,
        maxZoom: mapMaxZoom,
        // with the race on, rotation needs a real twist of the fingers
        enableMultiFingerGestureRace: true,
        rotationThreshold: mapRotationThreshold,
      ),
      children: [
        if (widget.withTiles) ...tileLayers(_layerType),
        ..._tracks(entries, chosen),
        if (phoneAt != null && targetAt != null) ...[
          PolylineLayer(polylines: [
            Polyline(
                points: [phoneAt, targetAt],
                color: Colors.white.withValues(alpha: 0.9),
                strokeWidth: 2,
                isDotted: true),
          ]),
          MarkerLayer(rotate: true, markers: [
            distanceMarker(
                LatLng((phoneAt.latitude + targetAt.latitude) / 2,
                    (phoneAt.longitude + targetAt.longitude) / 2),
                // ours, as on the card: latlong2's Distance can give "not a
                // number" and then fails on rounding (the red error screen)
                distanceBetween(phoneAt.latitude, phoneAt.longitude,
                    targetAt.latitude, targetAt.longitude)),
          ]),
        ],
        if (phoneAt != null)
          // turns with the map: the cone keeps pointing at the true heading
          MarkerLayer(markers: [
            phoneMarker(phoneAt.latitude, phoneAt.longitude,
                heading: _services.compass.reading?.heading),
          ]),
        MarkerLayer(
          rotate: true,
          markers: [
            // the chosen one on top of the others
            for (final e in [
              for (final e in entries)
                if (e != chosen) e,
              if (chosen != null) chosen,
            ])
              trackerMarker(e,
                  now: now, chosen: e == chosen, onTap: () => _choose(e)),
          ],
        ),
      ],
    );
  }

  /// where each tracker went: its last points, dotted, a dot at each; the
  /// chosen one brighter, a lost one paler
  List<Widget> _tracks(List<TrackerEntry> entries, TrackerEntry? chosen) {
    final signature = [
      for (final e in entries)
        if (_services.settings.isTrackShown(e.key))
          '${e.key}:${e.status.name}:${e == chosen}:'
              '${_services.store.pointsOf(e.key).length}:'
              '${_services.store.pointsOf(e.key).firstOrNull?.time.millisecondsSinceEpoch}',
    ].join('|');
    if (signature == _tracksSignature) return _tracksLayers;
    _tracksSignature = signature;
    return _tracksLayers = _buildTracks(entries, chosen);
  }

  List<Widget> _buildTracks(List<TrackerEntry> entries, TrackerEntry? chosen) {
    final polylines = <Polyline>[];
    final circles = <CircleMarker>[];
    for (final e in entries) {
      if (!_services.settings.isTrackShown(e.key)) continue;
      final points = [
        for (final p in _services.store.pointsOf(e.key))
          LatLng(p.latitude, p.longitude)
      ];
      if (points.length < 2) continue;
      final alpha = e == chosen
          ? 1.0
          : e.status == TrackerStatus.lost
              ? 0.5
              : 0.8;
      final color = Colors.white.withValues(alpha: alpha);
      polylines.add(Polyline(
          points: points,
          color: color,
          strokeWidth: e == chosen ? 3 : 2,
          isDotted: true));
      // the newest has its marker already
      for (final p in points.skip(1)) {
        circles.add(
            CircleMarker(point: p, radius: e == chosen ? 4 : 3, color: color));
      }
    }
    if (polylines.isEmpty) return const [];
    return [
      PolylineLayer(polylines: polylines),
      CircleLayer(circles: circles),
    ];
  }

  /// "След": which trackers' tracks are drawn
  Future<void> _chooseTracks(BuildContext context, List<TrackerEntry> entries) {
    final settings = _services.settings;
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            ListTile(
              title: Text(S.tracksTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: const Text(S.tracksHint),
            ),
            // all at once: untick everyone, then tick the ones to draw
            CheckboxListTile(
              title: const Text(S.tracksAll),
              tristate: true,
              value: entries.every((e) => settings.isTrackShown(e.key))
                  ? true
                  : entries.any((e) => settings.isTrackShown(e.key))
                      ? null
                      : false,
              onChanged: (_) => settings.setTracksShown(
                  entries.map((e) => e.key),
                  !entries.every((e) => settings.isTrackShown(e.key))),
            ),
            for (final e in entries)
              CheckboxListTile(
                title:
                    Text(displayName(e.name, alias: e.alias, mine: e.isMine)),
                value: settings.isTrackShown(e.key),
                onChanged: (v) => settings.setTrackShown(e.key, v ?? true),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _controls(
      BuildContext context, List<TrackerEntry> entries, TrackerEntry? chosen) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MapButton(
                tooltip: S.back,
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: AppSizes.gap),
              const Spacer(),
              const SizedBox(width: AppSizes.gap),
              Column(children: [
                _compassButton(),
                const SizedBox(height: AppSizes.gap),
                _layerButton(),
                const SizedBox(height: AppSizes.gap),
                _MapButton(
                  tooltip: S.whereAmI,
                  onTap: () => _whereAmI(context),
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: AppSizes.gap),
                _MapButton(
                  tooltip:
                      _followTracker ? S.followTrackerOff : S.followTracker,
                  pressed: _followTracker,
                  onTap: _toggleFollowTracker,
                  child: Icon(_followTracker
                      ? Icons.center_focus_strong
                      : Icons.center_focus_weak),
                ),
                const SizedBox(height: AppSizes.gap),
                _MapButton(
                  tooltip: S.tracks,
                  // dark while some track is drawn, as in the mockup
                  pressed: entries
                      .any((e) => _services.settings.isTrackShown(e.key)),
                  onTap: () => _chooseTracks(context, entries),
                  child: const Icon(Icons.timeline),
                ),
              ]),
            ],
          ),
          const Spacer(),
          if (chosen != null)
            _Panel(
              entries: entries,
              chosen: chosen,
              onChoose: _choose,
              trackShown: _services.settings.isTrackShown(chosen.key),
              onTrack: (v) => _services.settings.setTrackShown(chosen.key, v),
            ),
          // the map's sources (the licences ask for them), smallest, at the
          // very bottom under the card
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(3)),
              child: Text(
                mapAttribution(_layerType),
                style: const TextStyle(
                    fontSize: AppSizes.mapAttributionText,
                    height: 1.2,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compassButton() {
    final Widget icon;
    if (_followCompass) {
      icon = const Icon(Icons.navigation);
    } else {
      // the needle shows where north is on the rotated map
      icon = Transform.rotate(
        angle: _rotation * pi / 180,
        child: const CustomPaint(
            size: Size.square(26), painter: _NorthNeedlePainter()),
      );
    }
    return _MapButton(
      tooltip: _followCompass
          ? S.compassModeOff
          : (_isNorthUp ? S.compassModeOn : S.northUp),
      onTap: _onCompassButton,
      pressed: _followCompass,
      child: icon,
    );
  }

  Widget _layerButton() {
    return PopupMenuButton<MapLayerType>(
      tooltip: S.mapLayers,
      initialValue: _layerType,
      onSelected: (type) => setState(() => _layerType = type),
      itemBuilder: (context) => [
        for (final type in MapLayerType.values)
          CheckedPopupMenuItem<MapLayerType>(
            value: type,
            checked: type == _layerType,
            child: Text(mapLayerNames[type]!),
          ),
      ],
      child: const _MapButton(child: Icon(Icons.layers_outlined)),
    );
  }
}

/// a white square button over the map; [pressed]: dark, the mode is on
class _MapButton extends StatelessWidget {
  const _MapButton(
      {required this.child, this.onTap, this.tooltip, this.pressed = false});

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    const p = AppPalette.light; // white on any imagery, in every theme
    final button = Material(
      color: pressed ? p.ink : AppColors.mapControl,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          side: BorderSide(color: pressed ? p.ink : p.line)),
      child: InkWell(
        // no tap of its own inside the layers menu: the menu takes it
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: IconTheme(
              data: IconThemeData(color: pressed ? p.onInk : p.ink),
              child: Center(child: child)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// red to the north, dark to the south
class _NorthNeedlePainter extends CustomPainter {
  const _NorthNeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawPath(
        Path()
          ..moveTo(12 * s, 2 * s)
          ..lineTo(17 * s, 13 * s)
          ..lineTo(7 * s, 13 * s)
          ..close(),
        Paint()..color = AppColors.northNeedle);
    canvas.drawPath(
        Path()
          ..moveTo(12 * s, 22 * s)
          ..lineTo(7 * s, 13 * s)
          ..lineTo(17 * s, 13 * s)
          ..close(),
        Paint()..color = AppPalette.light.ink);
  }

  @override
  bool shouldRepaint(_NorthNeedlePainter old) => false;
}

/// the trackers to choose from and the chosen one's card
class _Panel extends StatelessWidget {
  const _Panel({
    required this.entries,
    required this.chosen,
    required this.onChoose,
    required this.trackShown,
    required this.onTrack,
  });

  final List<TrackerEntry> entries;
  final TrackerEntry chosen;
  final void Function(TrackerEntry) onChoose;

  /// the chosen tracker's track is drawn
  final bool trackShown;
  final void Function(bool) onTrack;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // a long press picks a chip up, as on the main screen
          SizedBox(
            height: AppSizes.minTap,
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
              onReorderItem: (from, to) {
                final keys = [for (final e in entries) e.key];
                keys.insert(to, keys.removeAt(from));
                AppScope.of(context).store.setOrder(keys);
              },
              children: [
                for (final e in entries)
                  Padding(
                    key: ValueKey(e.key),
                    padding: const EdgeInsets.only(right: AppSizes.gap),
                    child: _Chip(
                        entry: e,
                        chosen: e == chosen,
                        onTap: () => onChoose(e)),
                  ),
              ],
            ),
          ),
          TrackerCard(entry: chosen, framed: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
            child: Row(children: [
              const Icon(Icons.timeline),
              const SizedBox(width: AppSizes.gap),
              Expanded(
                  child: Text(S.trackOfChosen,
                      style: Theme.of(context).textTheme.bodyMedium)),
              Switch(value: trackShown, onChanged: onTrack),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.entry, required this.chosen, required this.onTap});

  final TrackerEntry entry;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final lost = entry.status == TrackerStatus.lost;
    final color = chosen
        ? p.onInk
        : lost
            ? p.muted
            : p.ink;
    return Semantics(
      selected: chosen,
      button: true,
      child: Material(
        color: chosen ? p.ink : Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            side: chosen
                ? BorderSide.none
                : BorderSide(color: p.line, width: AppSizes.outline)),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.minTap),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusDot(status: entry.status),
              const SizedBox(width: AppSizes.gap),
              Text(
                  displayName(entry.name,
                      alias: entry.alias, mine: entry.isMine),
                  style: TextStyle(
                      fontFamily: AppText.sans,
                      fontSize: AppText.small,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}
