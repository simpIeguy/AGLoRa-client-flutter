import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aglora/data.dart';
import '../aglora/memory.dart';
import '../utils/map_link.dart';

/// "53.902284, 27.561831": Google Maps understands it when pasted
String formatCoordinates(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

/// last received points of one tracker, the newest on top
class TrackerLogScreen extends StatelessWidget {
  const TrackerLogScreen(
      {Key? key, required this.identifier, this.openUrl = openExternally})
      : super(key: key);

  final String identifier;

  /// replaced in tests, so no real map app is needed
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Лог: $identifier')),
      body: StreamBuilder(
        // refreshes "N мин назад" and picks up new points
        stream: Stream.periodic(Duration(seconds: 1)),
        builder: (context, _) {
          final points = agloraAppMemory.pointsOf(identifier);
          if (points.isEmpty) {
            return Center(child: Text('Точек пока нет'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: Icon(Icons.map_outlined),
                    label: Text('Открыть в картах'),
                    onPressed: () => _openInMaps(context, points.first),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: points.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildPointTile(context, points[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// the newest point: where the tracker was last seen
  Future<void> _openInMaps(
      BuildContext context, AGLORATrackerPoint point) async {
    final opened = await openPointInMaps(
        point.latitude, point.longitude, point.identifier,
        open: openUrl);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text('Не удалось открыть карты на этом телефоне')));
  }

  Widget _buildPointTile(BuildContext context, AGLORATrackerPoint point) {
    final coordinates = formatCoordinates(point.latitude, point.longitude);

    final details = <String>[
      'Принято ${_formatTime(point.receivedAt)}, ${_formatAgo(point.receivedAt)}',
      'GPS-время ${_formatTime(point.time.toLocal())}',
    ];
    final extras = <String>[];
    final altitude = point.sensor('alt');
    if (altitude != null) extras.add('высота $altitude м');
    final speed = point.sensor('speed');
    if (speed != null) extras.add('скорость $speed');
    final satellites = point.sensor('sat');
    if (satellites != null) extras.add('спутники $satellites');
    final gpsValid = point.sensor('gpsValid');
    if (gpsValid != null) extras.add(gpsValid == '1' ? 'GPS ок' : 'GPS нет');
    final battery = point.sensor('battery');
    if (battery != null) extras.add('батарея $battery%');
    if (extras.isNotEmpty) details.add(extras.join(' · '));

    return ListTile(
      title: Text(coordinates,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontFeatures: [FontFeature.tabularFigures()])),
      subtitle: Text(details.join('\n')),
      isThreeLine: true,
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: coordinates));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Скопировано')));
      },
    );
  }

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  String _formatAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return '${difference.inSeconds} сек назад';
    if (difference.inHours < 1) return '${difference.inMinutes} мин назад';
    return '${difference.inHours} ч назад';
  }
}
