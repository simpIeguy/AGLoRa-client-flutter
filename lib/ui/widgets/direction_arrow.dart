import 'package:flutter/widgets.dart';

import '../../data/direction.dart';
import '../../services/app_services.dart';
import '../../util/geo.dart';
import '../strings.dart';

/// The direction from the phone to a point, kept fresh from the phone's GPS
/// and compass.
Direction currentDirection(
    AppServices services, double latitude, double longitude) {
  final phone = services.location.position;
  final reading = services.compass.reading;
  return directionTo(
    latitude: latitude,
    longitude: longitude,
    phoneLatitude: phone?.latitude,
    phoneLongitude: phone?.longitude,
    useCompass: services.compass.useCompass,
    hasCompassReading: reading != null,
    compassAccuracy: reading?.accuracy,
  );
}

String? directionProblemText(DirectionProblem problem) => switch (problem) {
      DirectionProblem.none => null,
      DirectionProblem.noPhonePosition => S.noPhonePosition,
      DirectionProblem.noCompass => S.noCompass,
      DirectionProblem.compassUnreliable => S.compassUnreliable,
    };

/// An arrow from the phone to [bearing]; turns with the phone's compass.
/// Without a bearing it stays still and takes [mutedColor].
///
/// The design's rule: the arrow never changes its color to say something.
/// Filled: the direction is to be trusted. Outline: approximate (the compass
/// is not accurate) or to a stale point (the link is lost, then in
/// [mutedColor]). Dashed, pointing nowhere: no direction at all.
class DirectionArrow extends StatelessWidget {
  const DirectionArrow({
    super.key,
    required this.bearing,
    required this.size,
    required this.color,
    required this.mutedColor,
    this.reliable = true,
    this.stale = false,
  });

  final double? bearing;
  final double size;
  final Color color;
  final Color mutedColor;

  /// false: the compass is not to be trusted, an outline
  final bool reliable;

  /// the point is old (the link is lost): a muted outline
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final compass = AppScope.of(context).compass;
    final target = bearing;
    if (target == null) {
      return ArrowShape(
          size: size, color: mutedColor, style: ArrowStyle.unavailable);
    }
    final style = reliable && !stale ? ArrowStyle.filled : ArrowStyle.outline;
    return ListenableBuilder(
      listenable: compass,
      builder: (context, _) => Transform.rotate(
        angle: arrowAngle(target, compass.arrowHeading),
        child: ArrowShape(
            size: size, color: stale ? mutedColor : color, style: style),
      ),
    );
  }
}

enum ArrowStyle { filled, outline, unavailable }

/// the arrow of the mockups, pointing up; [ArrowStyle] tells how to draw it
class ArrowShape extends StatelessWidget {
  const ArrowShape(
      {super.key,
      required this.size,
      required this.color,
      required this.style});

  final double size;
  final Color color;
  final ArrowStyle style;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(size), painter: _ArrowPainter(color, style));
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color, this.style);

  final Color color;
  final ArrowStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    // the mockups' path in a 24×24 box: "M12 2.5l7 18-7-4.5-7 4.5z"
    final k = size.width / 24;
    final path = Path()
      ..moveTo(12 * k, 2.5 * k)
      ..lineTo(19 * k, 20.5 * k)
      ..lineTo(12 * k, 16 * k)
      ..lineTo(5 * k, 20.5 * k)
      ..close();
    // a thin line looks the same on a small and a large arrow
    final stroke = (size.width <= 100 ? 1.6 : 0.55) * k;
    final paint = Paint()
      ..color = color
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = style == ArrowStyle.filled ? stroke / 2 : stroke
      ..style = PaintingStyle.stroke;

    switch (style) {
      case ArrowStyle.filled:
        canvas.drawPath(path, Paint()..color = color);
        canvas.drawPath(path, paint);
      case ArrowStyle.outline:
        canvas.drawPath(path, paint);
      case ArrowStyle.unavailable:
        canvas.drawPath(_dashed(path, 1.4 * k * 2, 1.2 * k * 2), paint);
    }
  }

  static Path _dashed(Path path, double dash, double gap) {
    final result = Path();
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        result.addPath(metric.extractPath(d, d + dash), Offset.zero);
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.color != color || old.style != style;
}
