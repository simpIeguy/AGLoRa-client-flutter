import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/tracker_status.dart';
import '../../services/app_services.dart';
import '../strings.dart';
import '../theme.dart';
import 'map/map_layers.dart';
import 'map/map_markers.dart';

/// degrees of two-finger twist before the map starts to rotate
const double mapRotationThreshold = 30;

/// 0..1, smaller is smoother but slower to follow the phone's compass
const double compassSmoothing = 0.15;

class MapScreen extends StatefulWidget {
  const MapScreen(
      {super.key, required this.centerLatitude, required this.centerLongitude});

  final double centerLatitude;
  final double centerLongitude;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  MapLayerType _layerType = MapLayerType.hybrid;

  double _rotation = 0; // degrees, as the map reports it
  bool _followCompass = false;
  double? _smoothedHeading;

  StreamSubscription<MapEvent>? _mapEventSubscription;

  late final AppServices _services = AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _mapEventSubscription = _mapController.mapEventStream.listen((event) {
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
    if (heading == null) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mapBackground,
      body: Stack(children: [
        FlutterMap(
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
            ...tileLayers(_layerType),
            ListenableBuilder(
              listenable: _services.location,
              builder: (context, _) {
                final phone = _services.location.position;
                if (phone == null) return const SizedBox.shrink();
                return MarkerLayer(rotate: true, markers: [
                  phoneMarker(phone.latitude, phone.longitude),
                ]);
              },
            ),
            ListenableBuilder(
              // new points and colors by timer
              listenable: Listenable.merge([_services.store, _services.clock]),
              builder: (context, _) {
                final now = _services.clock.now;
                final connected = _services.store.connectedTracker;
                return MarkerLayer(
                  rotate: true,
                  markers: [
                    for (final point in _services.store.latestPoints)
                      trackerMarker(context, point,
                          now: now,
                          status: trackerStatus(
                              time: point.time,
                              isConnected: point.identifier == connected,
                              now: now)),
                  ],
                );
              },
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.gap),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                          foregroundColor: AppColors.mapControlIcon,
                          minimumSize:
                              const Size(AppSizes.minTap, AppSizes.minTap)),
                      icon: const Icon(Icons.turn_left_outlined),
                      label: const Text(S.back),
                    ),
                    const Spacer(),
                    Column(children: [
                      _compassButton(),
                      const SizedBox(height: AppSizes.gap),
                      _layerButton(),
                    ]),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: AppColors.mapAttributionBackground,
                    child: Text(
                      mapAttribution(_layerType),
                      style: const TextStyle(
                          fontSize: AppSizes.mapAttributionText,
                          color: AppColors.onLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _compassButton() {
    final Widget icon;
    if (_followCompass) {
      icon = Icon(Icons.navigation, color: AppColors.connected);
    } else if (!_isNorthUp) {
      // the needle shows where north is on the rotated map
      icon = Transform.rotate(
        angle: _rotation * pi / 180,
        child: const Icon(CupertinoIcons.location_north_fill,
            color: AppColors.northNeedle),
      );
    } else {
      icon =
          const Icon(Icons.explore_outlined, color: AppColors.mapControlIcon);
    }
    return FloatingActionButton(
      heroTag: 'compass',
      backgroundColor: AppColors.mapControl,
      tooltip: _followCompass
          ? S.compassModeOff
          : (_isNorthUp ? S.compassModeOn : S.northUp),
      onPressed: _onCompassButton,
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
      child: const Material(
        color: AppColors.mapControl,
        shape: CircleBorder(),
        elevation: 4,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.layers_outlined, color: AppColors.mapControlIcon),
        ),
      ),
    );
  }
}
