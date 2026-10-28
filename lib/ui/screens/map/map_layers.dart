import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../strings.dart';

/// closest zoom the user can reach; above a source's maxNativeZoom its last
/// level is stretched, so the map never goes blank
const double mapMaxZoom = 20;
const double mapMinZoom = 3;

const String _userAgent = 'by.tsp.tracker';

enum MapLayerType { scheme, satellite, hybrid }

const Map<MapLayerType, String> mapLayerNames = {
  MapLayerType.scheme: S.layerScheme,
  MapLayerType.satellite: S.layerSatellite,
  MapLayerType.hybrid: S.layerHybrid,
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
List<Widget> tileLayers(MapLayerType type) => switch (type) {
      MapLayerType.scheme => [_osmLayer()],
      MapLayerType.satellite => [
          _esriLayer('World_Imagery', maxNativeZoom: 18)
        ],
      MapLayerType.hybrid => [
          _esriLayer('World_Imagery', maxNativeZoom: 18),
          _esriLayer('Reference/World_Transportation', maxNativeZoom: 18),
          _esriLayer('Reference/World_Boundaries_and_Places',
              maxNativeZoom: 18),
        ],
    };

String mapAttribution(MapLayerType type) => switch (type) {
      MapLayerType.scheme => _osmAttribution,
      MapLayerType.satellite => _esriImageryAttribution,
      MapLayerType.hybrid =>
        '$_esriImageryAttribution\n$_esriReferenceAttribution',
    };
