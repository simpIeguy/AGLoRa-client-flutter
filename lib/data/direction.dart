import '../util/geo.dart';

/// why the arrow and the distance can not be shown right
enum DirectionProblem { none, noPhonePosition, noCompass, compassUnreliable }

/// compass accuracy (degrees, from Android) at or above this is unreliable
const double compassUnreliableFrom = 45;

/// From the phone to a tracker's point. With a problem the screen shows a
/// grey arrow and the reason instead of a wrong value.
class Direction {
  const Direction({this.bearing, this.distance, required this.problem});

  /// degrees clockwise from north; null without the phone's position
  final double? bearing;

  /// metres; null without the phone's position
  final double? distance;

  final DirectionProblem problem;

  bool get isReliable => problem == DirectionProblem.none;
}

/// [useCompass] off: the arrow takes the top of the phone for north, so the
/// compass state does not matter
Direction directionTo({
  required double latitude,
  required double longitude,
  required double? phoneLatitude,
  required double? phoneLongitude,
  required bool useCompass,
  required bool hasCompassReading,
  double? compassAccuracy,
}) {
  if (phoneLatitude == null || phoneLongitude == null) {
    return const Direction(problem: DirectionProblem.noPhonePosition);
  }
  final bearing =
      bearingBetween(phoneLatitude, phoneLongitude, latitude, longitude);
  final distance =
      distanceBetween(phoneLatitude, phoneLongitude, latitude, longitude);

  var problem = DirectionProblem.none;
  if (useCompass && !hasCompassReading) {
    problem = DirectionProblem.noCompass;
  } else if (useCompass &&
      compassAccuracy != null &&
      compassAccuracy >= compassUnreliableFrom) {
    problem = DirectionProblem.compassUnreliable;
  }
  return Direction(bearing: bearing, distance: distance, problem: problem);
}
