import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../protocol/tracker_name.dart';
import '../../protocol/tracker_point.dart';
import '../../services/app_services.dart';
import '../../services/map_link.dart';
import '../format.dart';
import '../names.dart';
import '../strings.dart';
import '../theme.dart';

/// last received points of one tracker, the newest on top
class TrackerLogScreen extends StatelessWidget {
  const TrackerLogScreen({super.key, required this.identifier});

  final String identifier;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
          title: Text(S.logTitle(displayName(parseTrackerName(identifier),
              alias: services.store.aliasOf(identifier))))),
      body: ListenableBuilder(
        // refreshes "N мин назад" and picks up new points
        listenable: Listenable.merge([services.store, services.clock]),
        builder: (context, _) {
          final points = services.store.pointsOf(identifier);
          if (points.isEmpty) {
            return const Center(child: Text(S.noPointsYet));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSizes.padding),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text(S.openInMaps),
                    onPressed: () => _openInMaps(context, points.first),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: points.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _PointTile(point: points[index], now: services.clock.now),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// the newest point: where the tracker was last seen
  Future<void> _openInMaps(BuildContext context, TrackerPoint point) async {
    final opened = await openPointInMaps(
        point.latitude, point.longitude, point.identifier,
        open: AppScope.of(context).openUrl);
    if (opened || !context.mounted) return;
    showMessage(context, S.cannotOpenMaps);
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
  final text = formatCoordinates(latitude, longitude);
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showMessage(context, S.copiedValue(text));
}

class _PointTile extends StatelessWidget {
  const _PointTile({required this.point, required this.now});

  final TrackerPoint point;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      S.received(formatClock(point.receivedAt),
          formatAge(now.difference(point.receivedAt))),
      S.gpsTime(formatClock(point.time.toLocal())),
    ];
    final extras = <String>[];
    final altitude = point.sensor('alt');
    if (altitude != null) extras.add(S.altitude(altitude));
    final speed = point.sensor('speed');
    if (speed != null) extras.add(S.speed(speed));
    final satellites = point.sensor('sat');
    if (satellites != null) extras.add(S.satellites(satellites));
    final gpsValid = point.sensor('gpsValid');
    if (gpsValid != null) extras.add(gpsValid == '1' ? S.gpsOk : S.gpsNo);
    // no battery: the firmware does not measure it and always sends 100
    if (extras.isNotEmpty) details.add(extras.join(' · '));

    return ListTile(
      title: Text(formatCoordinates(point.latitude, point.longitude),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontFeatures: [const FontFeature.tabularFigures()])),
      subtitle: Text(details.join('\n')),
      isThreeLine: true,
      onLongPress: () =>
          copyCoordinates(context, point.latitude, point.longitude),
    );
  }
}
