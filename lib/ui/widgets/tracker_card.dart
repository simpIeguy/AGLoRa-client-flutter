import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/tracker_status.dart';
import '../../protocol/tracker_point.dart';
import '../../services/app_services.dart';
import '../../util/geo.dart';
import '../format.dart';
import '../screens/map_screen.dart';
import '../screens/tracker_log_screen.dart';
import '../strings.dart';
import '../theme.dart';
import 'direction_arrow.dart';

/// One tracker: colored by its status, with the direction and distance
/// from the phone. A tap opens its log.
class TrackerCard extends StatelessWidget {
  const TrackerCard({super.key, required this.point});

  /// the tracker's newest point
  final TrackerPoint point;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      // recolor by timer, without waiting for new data
      listenable: Listenable.merge([services.clock, services.location]),
      builder: (context, _) {
        final status = trackerStatus(
          time: point.time,
          isConnected: point.identifier == services.store.connectedTracker,
          now: services.clock.now,
        );
        final background = AppColors.status(status);
        final foreground = AppColors.readableOn(background);
        final phone = services.location.position;

        return Padding(
          padding: const EdgeInsets.all(AppSizes.gap),
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      TrackerLogScreen(identifier: point.identifier))),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.padding),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foreground),
                  child: Column(children: [
                    phone == null
                        ? _withoutPhonePosition(context)
                        : _withPhonePosition(context, phone.latitude,
                            phone.longitude, foreground),
                    _bottomRow(context, foreground, services.clock.now),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TextStyle? _value(BuildContext context, Color color) =>
      Theme.of(context).textTheme.titleLarge?.copyWith(color: color);

  Widget _labeled(String label, String value, TextStyle? style) {
    return Column(children: [Text(label), Text(value, style: style)]);
  }

  Widget _withPhonePosition(
      BuildContext context, double lat, double lon, Color foreground) {
    final bearing = bearingBetween(lat, lon, point.latitude, point.longitude);
    final distance = distanceBetween(lat, lon, point.latitude, point.longitude);
    final style = _value(context, foreground);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        DirectionArrow(
            bearing: bearing, size: AppSizes.cardArrow, color: foreground),
        _labeled(S.toTracker, formatBearing(bearing), style),
        Expanded(child: _labeled(S.distance, formatDistance(distance), style)),
        Expanded(child: _labeled(S.tracker, point.identifier, style)),
      ],
    );
  }

  Widget _withoutPhonePosition(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: Column(children: [
            const Text(S.coordinates),
            Text('${point.latitude.toStringAsFixed(6)},',
                style: textTheme.bodyLarge?.copyWith(color: color)),
            Text(point.longitude.toStringAsFixed(6),
                style: textTheme.bodyLarge?.copyWith(color: color)),
          ]),
        ),
        Expanded(
          child: Column(children: [
            const Text(S.tracker),
            Text(point.identifier,
                style: textTheme.headlineSmall?.copyWith(color: color)),
          ]),
        ),
      ],
    );
  }

  Widget _bottomRow(BuildContext context, Color foreground, DateTime now) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MapScreen(
                  centerLatitude: point.latitude,
                  centerLongitude: point.longitude))),
          icon: Icon(CupertinoIcons.map_pin_ellipse, color: foreground),
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground,
            side: BorderSide(color: foreground),
          ),
          label: const Text(S.map),
        ),
        Expanded(child: Center(child: _sensors())),
        Expanded(
            child: Center(
                child: Text(formatAge(now.toUtc().difference(point.time))))),
      ],
    );
  }

  Widget _sensors() {
    if (point.sensors.isEmpty) return const SizedBox.shrink();
    final lines = [
      S.sensors,
      for (final s in point.sensors) '${s.name}: ${s.value}',
    ];
    return Text(lines.join('\n'));
  }
}
