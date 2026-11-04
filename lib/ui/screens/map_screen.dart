import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../data/landmark.dart';
import '../../data/tracker_list.dart';
import '../../data/tracker_status.dart';
import '../../data/tracker_store.dart';
import '../../services/app_services.dart';
import '../../util/geo.dart';
import '../names.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/ask_location.dart';
import '../widgets/drag_proxy.dart';
import '../widgets/status_dot.dart';
import '../widgets/steady_reorder_list.dart';
import '../widgets/tracker_card.dart';
import 'map/landmark_sheet.dart';
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
    this.followChosen = false,
    this.withTiles = true,
  });

  final double centerLatitude;
  final double centerLongitude;

  /// the tracker to show first; the most important one when null
  final String? chosen;

  /// start with the map kept on [chosen] ("Показать на карте" of a tracker)
  final bool followChosen;

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
  late bool _followTracker = widget.followChosen && widget.chosen != null;

  /// where the line leads: one landmark or one tracker, never both; none: no
  /// line (a tracker looked at is not a tracker walked to)
  int? _landmarkId;
  String? _aimTracker;

  /// the panel at the bottom is open; folded, only the chosen name is left
  bool _panelOpen = true;

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
    setState(() {
      _chosen = entry.key;
    });
    final point = entry.latest!;
    _mapController.move(
        LatLng(point.latitude, point.longitude), _mapController.zoom);
  }

  /// a landmark was added or picked in the list: the map goes to it, the line
  /// leads to it
  void _showLandmark(Landmark landmark) {
    _services.settings.setLandmarkVisible(landmark.id, true);
    setState(() {
      _landmarkId = landmark.id;
      _aimTracker = null;
      _followTracker = false;
    });
    _mapController.move(
        LatLng(landmark.latitude, landmark.longitude), _mapController.zoom);
  }

  /// a landmark picked in the list: the map goes to it, the line stays
  void _goToLandmark(Landmark landmark) {
    _services.settings.setLandmarkVisible(landmark.id, true);
    setState(() => _followTracker = false);
    _mapController.move(
        LatLng(landmark.latitude, landmark.longitude), _mapController.zoom);
  }

  /// "Линия до метки" in the list: the line leads to it, or stops;
  /// true when it leads now
  bool _aimAtLandmark(Landmark landmark) {
    final shown = _services.settings.landmarks
        .any((l) => l.id == landmark.id && l.visible);
    final on = !(shown && _landmarkId == landmark.id);
    if (on) _services.settings.setLandmarkVisible(landmark.id, true);
    setState(() {
      _landmarkId = on ? landmark.id : null;
      _aimTracker = null;
    });
    return on;
  }

  /// a tap on a flag: the line leads to it, or back to the tracker
  void _tapLandmark(Landmark landmark) => setState(() {
        _landmarkId = _landmarkId == landmark.id ? null : landmark.id;
        _aimTracker = null;
      });

  /// the switch in the card: lead to this tracker, or stop
  void _aimAt(String key, bool on) => setState(() {
        _aimTracker = on ? key : null;
        _landmarkId = null;
      });

  /// the 6° zone of the map's middle, for coordinates told without one
  int _mapZone() {
    double lon;
    try {
      lon = _mapController.center.longitude;
    } catch (_) {
      lon = widget.centerLongitude;
    }
    return (((lon % 360) + 360) % 360 / 6).floor() + 1;
  }

  /// the + and − buttons: one step of zoom, within the limits of the map
  void _zoomBy(double step) {
    final zoom = (_mapController.zoom + step).clamp(mapMinZoom, mapMaxZoom);
    _mapController.move(_mapController.center, zoom.toDouble());
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
    // the buttons and labels sit on the map: a huge system font would cover it
    return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3, child: _scaffold(context));
  }

  Widget _scaffold(BuildContext context) {
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
          final shown = [
            for (final e in buildTrackerList(_services.store, now).shown)
              if (e.latest != null) e
          ];
          // the user's own tracker sits where the phone is: hidden unless asked
          final entries = [
            for (final e in shown)
              if (_services.settings.isOnMap(e.key, mine: e.isMine)) e
          ];
          final chosen = entries.where((e) => e.key == _chosen).firstOrNull ??
              entries.firstOrNull;
          _followChosen(chosen);
          return Stack(children: [
            Semantics(label: S.map, child: _map(context, entries, chosen, now)),
            SafeArea(child: _controls(context, entries, chosen, shown)),
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
    final landmarks = _services.settings.landmarks;
    // the line leads to a landmark only while it is shown
    final landmark =
        landmarks.where((l) => l.id == _landmarkId && l.visible).firstOrNull;
    final target =
        entries.where((e) => e.key == _aimTracker).firstOrNull?.latest;
    final targetAt = landmark != null
        ? LatLng(landmark.latitude, landmark.longitude)
        : target == null
            ? null
            : LatLng(target.latitude, target.longitude);
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
                    targetAt.latitude, targetAt.longitude),
                bearingBetween(phoneAt.latitude, phoneAt.longitude,
                    targetAt.latitude, targetAt.longitude)),
          ]),
        ],
        if (phoneAt != null)
          // turns with the map: the cone keeps pointing at the true heading
          MarkerLayer(markers: [
            phoneMarker(phoneAt.latitude, phoneAt.longitude,
                heading: _services.compass.reading?.heading,
                course: phone?.movingCourse),
          ]),
        MarkerLayer(
          rotate: true,
          markers: [
            for (final l in landmarks)
              if (l.visible)
                landmarkMarker(l,
                    chosen: l.id == landmark?.id, onTap: () => _tapLandmark(l)),
          ],
        ),
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
    return showAppSheet<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SafeArea(
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              shrinkWrap: true,
              children: [
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
                    title: Text(
                        displayName(e.name, alias: e.alias, mine: e.isMine)),
                    value: settings.isTrackShown(e.key),
                    onChanged: (v) => settings.setTrackShown(e.key, v ?? true),
                  ),
              ]),
        ),
      ),
    );
  }

  /// "Какие трекеры показывать": which of them are on the map at all
  Future<void> _chooseOnMap(BuildContext context, List<TrackerEntry> all) {
    final settings = _services.settings;
    bool on(TrackerEntry e) => settings.isOnMap(e.key, mine: e.isMine);
    return showAppSheet<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SafeArea(
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(S.onMapTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                CheckboxListTile(
                  title: const Text(S.tracksAll),
                  tristate: true,
                  value: all.every(on)
                      ? true
                      : all.any(on)
                          ? null
                          : false,
                  onChanged: (_) {
                    final target = !all.every(on);
                    for (final e in all) {
                      settings.setOnMap(e.key, target, mine: e.isMine);
                    }
                  },
                ),
                for (final e in all)
                  CheckboxListTile(
                    title: Text(
                        displayName(e.name, alias: e.alias, mine: e.isMine)),
                    value: on(e),
                    onChanged: (v) =>
                        settings.setOnMap(e.key, v ?? true, mine: e.isMine),
                  ),
              ]),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, List<TrackerEntry> entries,
      TrackerEntry? chosen, List<TrackerEntry> candidates) {
    final settings = _services.settings;
    return Padding(
      padding: const EdgeInsets.all(AppSizes.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                _MapButton(
                  tooltip: S.back,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back),
                ),
                const SizedBox(height: AppSizes.gap),
                _MapButton(
                  tooltip: S.landmarks,
                  pressed: settings.landmarks.isNotEmpty,
                  onTap: () => showLandmarkSheet(context,
                      zone: _mapZone(),
                      onShow: _showLandmark,
                      onGo: _goToLandmark,
                      onAim: _aimAtLandmark,
                      aimedId: _landmarkId),
                  child: const Icon(Icons.add_location_alt_outlined),
                ),
                const SizedBox(height: AppSizes.gap),
                _MapButton(
                  tooltip: S.zoomIn,
                  onTap: () => _zoomBy(1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: AppSizes.gap),
                _MapButton(
                  tooltip: S.zoomOut,
                  onTap: () => _zoomBy(-1),
                  child: const Icon(Icons.remove),
                ),
              ]),
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
          if (chosen == null && candidates.isNotEmpty)
            // all taken off the map: the way back must stay
            _HiddenPanel(
                onFilter: () => _chooseOnMap(context, candidates),
                hidden: candidates.length),
          if (chosen != null)
            _Panel(
              onFilter: () => _chooseOnMap(context, candidates),
              hidden: candidates.length - entries.length,
              entries: entries,
              chosen: chosen,
              onChoose: _choose,
              trackShown: _services.settings.isTrackShown(chosen.key),
              onTrack: (v) => _services.settings.setTrackShown(chosen.key, v),
              open: _panelOpen,
              onToggle: () => setState(() => _panelOpen = !_panelOpen),
              aimed: _aimTracker == chosen.key,
              onAim: (v) => _aimAt(chosen.key, v),
            ),
          // the map's sources (the licences ask for them), smallest, at the
          // very bottom under the card
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
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

/// the card when every tracker is taken off the map: only the way back
class _HiddenPanel extends StatelessWidget {
  const _HiddenPanel({required this.onFilter, required this.hidden});

  final int hidden;

  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Row(children: [
        IconButton(
          tooltip: S.onMapTooltip,
          icon: Badge(
              label: Text('$hidden'),
              child: const Icon(Icons.visibility_off_outlined)),
          onPressed: onFilter,
        ),
        Expanded(
            child: Text(S.allOffMap,
                style: Theme.of(context).textTheme.bodyMedium)),
      ]),
    );
  }
}

/// the trackers to choose from and the chosen one's card
class _Panel extends StatelessWidget {
  const _Panel({
    required this.entries,
    required this.chosen,
    required this.onChoose,
    required this.trackShown,
    required this.onTrack,
    required this.onFilter,
    required this.hidden,
    required this.open,
    required this.onToggle,
    required this.aimed,
    required this.onAim,
  });

  final List<TrackerEntry> entries;
  final TrackerEntry chosen;
  final void Function(TrackerEntry) onChoose;

  /// the chosen tracker's track is drawn
  final bool trackShown;
  final void Function(bool) onTrack;

  /// opens the list of the trackers to show on the map
  final VoidCallback onFilter;

  /// how many trackers are taken off the map
  final int hidden;

  /// unfolded: the chips and the card; folded: a single line
  final bool open;
  final VoidCallback onToggle;

  /// the line on the map leads to the chosen tracker
  final bool aimed;
  final void Function(bool) onAim;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      // folded, the single line sits in the middle between top and bottom
      padding: EdgeInsets.symmetric(vertical: open ? 0 : AppSizes.gap)
          .copyWith(top: AppSizes.gap),
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const SizedBox(width: AppSizes.gap),
            _PanelButton(
              tooltip: open ? S.panelFold : S.panelUnfold,
              icon: open ? Icons.expand_more : Icons.expand_less,
              onTap: onToggle,
            ),
            const SizedBox(width: AppSizes.gap),
            _PanelButton(
              tooltip: S.onMapTooltip,
              icon: hidden > 0
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              badge: hidden,
              onTap: onFilter,
            ),
            Expanded(
              child: SizedBox(
                height: AppSizes.minTap,
                child: open
                    // a long press picks a chip up, as on the main screen;
                    // the chips fade out at the edges instead of being cut
                    ? ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black,
                            Colors.black,
                            Colors.transparent
                          ],
                          stops: [0, 0.04, 0.96, 1],
                        ).createShader(r),
                        child: SteadyReorderList<TrackerEntry>(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.padding),
                          proxyDecorator: dragProxy(AppSizes.buttonRadius,
                              color: p.card,
                              gap: const EdgeInsets.only(right: AppSizes.gap)),
                          items: entries,
                          keyOf: (e) => e.key,
                          onOrder: AppScope.of(context).store.setOrder,
                          itemBuilder: (e) => Padding(
                            key: ValueKey(e.key),
                            padding: const EdgeInsets.only(right: AppSizes.gap),
                            child: _Chip(
                                entry: e,
                                chosen: e.key == chosen.key,
                                onTap: () => onChoose(e)),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.padding),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              displayName(chosen.name,
                                  alias: chosen.alias, mine: chosen.isMine),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                      ),
              ),
            ),
          ]),
          if (open) ...[
            TrackerCard(entry: chosen, framed: false),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
              child: MergeSemantics(
                child: Row(children: [
                  const Icon(Icons.navigation_outlined),
                  const SizedBox(width: AppSizes.gap),
                  Expanded(
                      child: Text(S.aimAtTracker,
                          style: Theme.of(context).textTheme.bodyMedium)),
                  Switch(value: aimed, onChanged: onAim),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
              // one node for the screen reader: "След, switch"
              child: MergeSemantics(
                child: Row(children: [
                  const Icon(Icons.timeline),
                  const SizedBox(width: AppSizes.gap),
                  Expanded(
                      child: Text(S.trackOfChosen,
                          style: Theme.of(context).textTheme.bodyMedium)),
                  Switch(value: trackShown, onChanged: onTrack),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// a round-cornered square button of the panel, like the chips beside it
class _PanelButton extends StatelessWidget {
  const _PanelButton(
      {required this.tooltip,
      required this.icon,
      required this.onTap,
      this.badge = 0});

  final String tooltip;
  final IconData icon;

  /// a number on the corner, when above zero
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        side: BorderSide(color: p.line));
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox.square(
              dimension: AppSizes.minTap,
              child: badge > 0
                  ? Badge(
                      label: Text('$badge'),
                      alignment: AlignmentDirectional.topEnd,
                      child: Center(child: Icon(icon, color: p.ink)))
                  : Icon(icon, color: p.ink)),
        ),
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
