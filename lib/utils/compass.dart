import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:tsp_tracker/utils/saved_parameters.dart';

var compassStreamController = StreamController<double>.broadcast();

Stream<double> get compassDataStream => compassStreamController.stream;

void newHeading(double newHeading) {
  if (compassStreamController.hasListener && useCompass) {
    compassStreamController.add(newHeading);
  }
}

void startCompassListener() {
  try {
    FlutterCompass.events?.listen((event) {
      newHeading(event.heading ?? 0);
    });
  } catch (e) {
    if (kDebugMode) print('Error in startCompassListener: $e');
  }
  ;
}

/// any angle in degrees to 0 <= result < 360
double normalizeDegrees(double degrees) => (degrees % 360 + 360) % 360;

/// rotation (radians, clockwise) of an "up" arrow so it points at a target:
/// [bearing] is the direction to the target, [phoneHeading] is where the top
/// of the phone points (0 when the compass is off: the top is taken as north)
double arrowAngle(double bearing, double phoneHeading) =>
    normalizeDegrees(bearing - phoneHeading) * pi / 180;

const List<String> _compassPoints = [
  'С',
  'СВ',
  'В',
  'ЮВ',
  'Ю',
  'ЮЗ',
  'З',
  'СЗ'
];

/// 8-point compass name of a direction in degrees
String compassPoint(num degrees) =>
    _compassPoints[((normalizeDegrees(degrees.toDouble()) + 22.5) ~/ 45) % 8];

void enableCompass() {}

void disableCompass() {
  compassStreamController.add(0);
}
