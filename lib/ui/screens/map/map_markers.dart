import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../data/tracker_list.dart';
import '../../../data/tracker_status.dart';
import '../../format.dart';
import '../../names.dart';
import '../../theme.dart';

/// The markers lie on imagery of any color: they keep the light palette in
/// every theme, white labels with dark text, white rims.
const AppPalette _onMap = AppPalette.light;

/// the phone: a white dot with a dark rim and, with a compass, a pale cone
/// where the phone points
Marker phoneMarker(double latitude, double longitude, {double? heading}) =>
    Marker(
      width: 140,
      height: 140,
      point: LatLng(latitude, longitude),
      builder: (_) => CustomPaint(painter: _PhonePainter(heading)),
    );

class _PhonePainter extends CustomPainter {
  _PhonePainter(this.heading);

  /// degrees from north; the marker turns with the map, so north is up here
  final double? heading;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final h = heading;
    if (h != null) {
      const half = 30 * pi / 180, r = 68.0;
      final a = (h - 90) * pi / 180;
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..arcTo(Rect.fromCircle(center: c, radius: r), a - half, 2 * half,
                false)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: 0.28));
    }
    canvas.drawCircle(c, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        10,
        Paint()
          ..color = _onMap.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_PhonePainter old) => old.heading != heading;
}

/// a dot colored by status and a label "БЛА 1 · 12 с" above it; the chosen
/// one gets a ring
Marker trackerMarker(TrackerEntry entry,
    {required DateTime now,
    required bool chosen,
    required VoidCallback onTap}) {
  final point = entry.latest!;
  final lost = entry.status == TrackerStatus.lost;
  final heard = entry.lastHeard;
  final age =
      heard == null ? '' : formatDuration(now.toUtc().difference(heard));
  final Color dot = switch (entry.status) {
    TrackerStatus.connected || TrackerStatus.active => _onMap.green,
    TrackerStatus.fading => _onMap.amber,
    _ => Colors.black.withValues(alpha: 0.4),
  };
  return Marker(
    width: 200,
    height: 100,
    point: LatLng(point.latitude, point.longitude),
    builder: (_) => GestureDetector(
      onTap: onTap,
      child: Stack(alignment: Alignment.center, children: [
        if (chosen)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
          ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3)),
        ),
        Positioned(
          top: 0,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
            child: Text(
                '${displayName(entry.name, alias: entry.alias, mine: entry.isMine)} · $age',
                style: TextStyle(
                    fontFamily: AppText.sans,
                    fontSize: AppText.small,
                    fontWeight: FontWeight.w600,
                    color: lost ? _onMap.muted : _onMap.ink)),
          ),
        ),
      ]),
    ),
  );
}

/// "1,2 км" in the middle of the line from the phone to the chosen tracker
Marker distanceMarker(LatLng at, double metres) => Marker(
      width: 120,
      height: 28,
      point: at,
      builder: (_) => Center(
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Text(formatDistance(metres),
              style: TextStyle(
                  fontFamily: AppText.sans,
                  fontSize: AppText.small,
                  fontWeight: FontWeight.w700,
                  color: _onMap.ink)),
        ),
      ),
    );
