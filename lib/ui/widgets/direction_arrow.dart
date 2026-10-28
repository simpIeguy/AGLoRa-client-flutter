import 'package:flutter/cupertino.dart';

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
class DirectionArrow extends StatelessWidget {
  const DirectionArrow({
    super.key,
    required this.bearing,
    required this.size,
    required this.color,
    required this.mutedColor,
    this.reliable = true,
  });

  final double? bearing;
  final double size;
  final Color color;
  final Color mutedColor;

  /// false: the compass is not to be trusted, the arrow goes grey
  final bool reliable;

  @override
  Widget build(BuildContext context) {
    final compass = AppScope.of(context).compass;
    final target = bearing;
    if (target == null) {
      return Icon(CupertinoIcons.question_circle,
          size: size, color: mutedColor);
    }
    return ListenableBuilder(
      listenable: compass,
      builder: (context, _) => Transform.rotate(
        angle: arrowAngle(target, compass.arrowHeading),
        child: Icon(CupertinoIcons.arrow_up_circle,
            size: size, color: reliable ? color : mutedColor),
      ),
    );
  }
}
