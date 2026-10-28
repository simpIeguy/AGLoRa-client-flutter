import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aglora/data.dart';
import '../aglora/memory.dart';

/// "53.902284, 27.561831": Google Maps understands it when pasted
String formatCoordinates(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

/// last received points of one tracker, the newest on top
class TrackerLogScreen extends StatelessWidget {
  const TrackerLogScreen({Key? key, required this.identifier})
      : super(key: key);

  final String identifier;

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
          return ListView.separated(
            itemCount: points.length,
            separatorBuilder: (_, __) => Divider(height: 1),
            itemBuilder: (context, index) =>
                _buildPointTile(context, points[index]),
          );
        },
      ),
    );
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
