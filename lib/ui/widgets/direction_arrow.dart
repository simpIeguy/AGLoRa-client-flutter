import 'package:flutter/cupertino.dart';

import '../../services/app_services.dart';
import '../../util/geo.dart';

/// An arrow from the phone to [bearing]; turns with the phone's compass.
class DirectionArrow extends StatelessWidget {
  const DirectionArrow({
    super.key,
    required this.bearing,
    required this.size,
    required this.color,
  });

  final double bearing;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final compass = AppScope.of(context).compass;
    return ListenableBuilder(
      listenable: compass,
      builder: (context, _) => Transform.rotate(
        angle: arrowAngle(bearing, compass.arrowHeading),
        child: Icon(CupertinoIcons.arrow_up_circle, size: size, color: color),
      ),
    );
  }
}
