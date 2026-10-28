import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../aglora/data.dart';
import '../aglora/memory.dart';
import '../utils/tracker_status.dart';

/// closest zoom the user can reach; above a source's maxNativeZoom its last
/// level is stretched, so the map never goes blank
const double mapMaxZoom = 20;
const double mapMinZoom = 3;

/// degrees of two-finger twist before the map starts to rotate
const double mapRotationThreshold = 30;

/// 0..1, smaller is smoother but slower to follow the phone's compass
const double compassSmoothing = 0.15;

const String _userAgent = 'com.example.aglora_client';

enum MapLayerType { scheme, satellite, hybrid }

const Map<MapLayerType, String> mapLayerNames = {
  MapLayerType.scheme: 'Схема',
  MapLayerType.satellite: 'Спутник',
  MapLayerType.hybrid: 'Гибрид',
};

const String _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String _esriUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/{service}/MapServer/tile/{z}/{y}/{x}';

const String _osmAttribution = '© OpenStreetMap contributors';
const String _esriImageryAttribution =
    'Imagery © Esri, Vantor, Earthstar Geographics, GIS User Community';
const String _esriReferenceAttribution =
    'Labels © Esri, HERE, Garmin, © OpenStreetMap contributors';

TileLayer _osmLayer() => TileLayer(
      urlTemplate: _osmUrl,
      userAgentPackageName: _userAgent,
      maxZoom: mapMaxZoom,
      maxNativeZoom: 19,
    );

TileLayer _esriLayer(String service, {required int maxNativeZoom}) => TileLayer(
      urlTemplate: _esriUrl,
      additionalOptions: {'service': service},
      userAgentPackageName: _userAgent,
      maxZoom: mapMaxZoom,
      maxNativeZoom: maxNativeZoom,
      // overlays must not hide the imagery under them
      backgroundColor: Colors.transparent,
    );

// imagery goes to 19 in cities but often only to 18 in the countryside
List<Widget> _tileLayers(MapLayerType type) {
  switch (type) {
    case MapLayerType.scheme:
      return [_osmLayer()];
    case MapLayerType.satellite:
      return [_esriLayer('World_Imagery', maxNativeZoom: 18)];
    case MapLayerType.hybrid:
      return [
        _esriLayer('World_Imagery', maxNativeZoom: 18),
        _esriLayer('Reference/World_Transportation', maxNativeZoom: 18),
        _esriLayer('Reference/World_Boundaries_and_Places', maxNativeZoom: 18),
      ];
  }
}

String _attribution(MapLayerType type) {
  switch (type) {
    case MapLayerType.scheme:
      return _osmAttribution;
    case MapLayerType.satellite:
      return _esriImageryAttribution;
    case MapLayerType.hybrid:
      return '$_esriImageryAttribution\n$_esriReferenceAttribution';
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen(
      {Key? key, required this.centerLatitude, required this.centerLongitude})
      : super(key: key);

  final double centerLatitude;
  final double centerLongitude;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final Stream<void> _tick =
      Stream<void>.periodic(Duration(seconds: 1)).asBroadcastStream();

  MapLayerType _layerType = MapLayerType.hybrid;

  double _rotation = 0; // degrees, as the map reports it
  bool _followCompass = false;
  double? _smoothedHeading;

  StreamSubscription<MapEvent>? _mapEventSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

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
    _compassSubscription?.cancel();
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

  void _startFollowingCompass() {
    _smoothedHeading = null;
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
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
    });
    setState(() => _followCompass = true);
  }

  void _stopFollowingCompass() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
    setState(() => _followCompass = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // shown while tiles load, instead of a black screen
      backgroundColor: Colors.grey.shade300,
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
            ..._tileLayers(_layerType),
            StreamBuilder<Position>(
                stream: Geolocator.getPositionStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return SizedBox.shrink();
                  return MarkerLayer(rotate: true, markers: [
                    _buildAvatar(
                        context,
                        LatLng(
                            snapshot.data!.latitude, snapshot.data!.longitude)),
                  ]);
                }),
            StreamBuilder<void>(
                // new points and colors by timer
                stream: _tick,
                builder: (context, _) => MarkerLayer(
                      rotate: true,
                      markers: _buildMarkers(context, agloraAppMemory.trackers),
                    )),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.turn_left_outlined,
                          color: Colors.black,
                        ),
                        label: Text(
                          'Back',
                          style: Theme.of(context)
                              .primaryTextTheme
                              .labelLarge
                              ?.copyWith(color: Colors.black),
                        )),
                    Spacer(),
                    Column(
                      children: [
                        _buildCompassButton(),
                        SizedBox(height: 8),
                        _buildLayerButton(),
                      ],
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.white.withOpacity(0.7),
                    child: Text(
                      _attribution(_layerType),
                      style: TextStyle(fontSize: 10, color: Colors.black),
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

  Widget _buildCompassButton() {
    final Widget icon;
    if (_followCompass) {
      icon = Icon(Icons.navigation, color: Colors.blue);
    } else if (!_isNorthUp) {
      // the needle shows where north is on the rotated map
      icon = Transform.rotate(
        angle: _rotation * pi / 180,
        child: Icon(CupertinoIcons.location_north_fill, color: Colors.red),
      );
    } else {
      icon = Icon(Icons.explore_outlined, color: Colors.black87);
    }
    return FloatingActionButton.small(
      heroTag: 'compass',
      backgroundColor: Colors.white,
      tooltip: _followCompass
          ? 'Обычный режим'
          : (_isNorthUp ? 'По направлению телефона' : 'Север вверх'),
      onPressed: _onCompassButton,
      child: icon,
    );
  }

  Widget _buildLayerButton() {
    return PopupMenuButton<MapLayerType>(
      tooltip: 'Слои карты',
      initialValue: _layerType,
      onSelected: (type) => setState(() => _layerType = type),
      itemBuilder: (context) => MapLayerType.values
          .map((type) => CheckedPopupMenuItem<MapLayerType>(
                value: type,
                checked: type == _layerType,
                child: Text(mapLayerNames[type]!),
              ))
          .toList(),
      child: Material(
        color: Colors.white,
        shape: CircleBorder(),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(Icons.layers_outlined, color: Colors.black87),
        ),
      ),
    );
  }
}

Marker _buildAvatar(dynamic context, LatLng position) {
  return Marker(
    width: 80.0,
    height: 80.0,
    point: position,
    builder: (ctx) => Container(
      child: Column(
        children: [
          Icon(
            CupertinoIcons.location_solid,
            color: Colors.blueAccent,
          ),
        ],
      ),
    ),
  );
}

List<Marker> _buildMarkers(
    dynamic context, List<AGLORATrackerPoint> _trackersDataList) {
  return _trackersDataList.map((e) {
    final statusColor = trackerStatusColor(trackerStatusOf(e));
    return Marker(
      width: 150.0,
      height: 100.0,
      point: LatLng(e.latitude, e.longitude),
      builder: (ctx) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.map_pin_ellipse,
            color: statusColor,
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: statusColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: Offset(0, 3), // changes position of shadow
                ),
              ],
              borderRadius: BorderRadius.all(
                Radius.circular(15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    e.identifier,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .titleMedium
                        ?.copyWith(color: Colors.black),
                  ),
                  Text(
                    _timeAgo(e.time),
                    style: Theme.of(context)
                        .primaryTextTheme
                        .titleSmall
                        ?.copyWith(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }).toList();
}

String _timeAgo(DateTime time) {
  final difference = DateTime.now().toUtc().difference(time);
  return difference.inMinutes < 1
      ? '${difference.inSeconds} sec'
      : '${difference.inMinutes} min';
}
