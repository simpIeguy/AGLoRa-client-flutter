import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/tracker_status.dart';
import '../../../protocol/tracker_point.dart';
import '../../format.dart';
import '../../theme.dart';

Marker phoneMarker(double latitude, double longitude) => Marker(
      width: 80.0,
      height: 80.0,
      point: LatLng(latitude, longitude),
      builder: (_) => const Column(children: [
        Icon(CupertinoIcons.location_solid, color: AppColors.phoneMarker),
      ]),
    );

/// a pin and a label with the name and the age, colored by status
Marker trackerMarker(BuildContext context, TrackerPoint point,
    {required TrackerStatus status, required DateTime now}) {
  final statusColor = AppColors.status(status);
  final textTheme = Theme.of(context).textTheme;
  return Marker(
    width: 150.0,
    height: 100.0,
    point: LatLng(point.latitude, point.longitude),
    builder: (_) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CupertinoIcons.map_pin_ellipse, color: statusColor),
        Container(
          decoration: BoxDecoration(
            color: AppColors.mapControl,
            border: Border.all(color: statusColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.markerShadow,
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.gap),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(point.identifier,
                    style: textTheme.titleMedium
                        ?.copyWith(color: AppColors.onLight)),
                Text(formatAge(now.toUtc().difference(point.time)),
                    style: textTheme.titleSmall
                        ?.copyWith(color: AppColors.mutedText)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
