import 'dart:async';

import 'package:flutter/foundation.dart';

import '../util/geo.dart';
import 'app_settings.dart';
import 'compass_service.dart';
import 'location_service.dart';

/// speed (m/s) from which the walk's GPS course is taken
const double courseOnFrom = 1.0;

/// speed (m/s) below which the arrows go back to the compass; lower than
/// [courseOnFrom], so a speed hovering near the limit does not flip them
const double courseOffBelow = 0.6;

/// Where the top of the phone is taken to point, for the arrows.
///
/// Usually the compass. With the setting on and the phone moving at walking
/// speed, the GPS course instead (the compass says where the phone points,
/// the course where the person goes). The switch between the two is eased out
/// over about half a second so the arrows do not jump.
class HeadingService extends ChangeNotifier {
  HeadingService(this._compass, this._location, this._settings) {
    _compass.addListener(_onSensor);
    _location.addListener(_onSensor);
    _settings.addListener(_onSensor);
  }

  final CompassService _compass;
  final LocationService _location;
  final AppSettings _settings;

  bool _usingCourse = false;
  double _course = 0;

  /// what is still left of a jump between the two sources, degrees; shrinks
  /// to zero on [_ease]
  double _offset = 0;
  Timer? _ease;

  /// true while the arrows follow the GPS course
  bool get usingCourse => _usingCourse;

  /// what the arrows turn by, degrees from north
  double get arrowHeading => normalizeDegrees(
      (_usingCourse ? _course : _compass.arrowHeading) + _offset);

  void _onSensor() {
    final before = arrowHeadingWithoutOffset;
    final wasUsingCourse = _usingCourse;
    _update();
    if (_usingCourse != wasUsingCourse) {
      // start the ease from where the arrow was: shortest way round
      _offset = _shortest(before - arrowHeadingWithoutOffset + _offset);
      _startEase();
    }
    notifyListeners();
  }

  double get arrowHeadingWithoutOffset =>
      _usingCourse ? _course : _compass.arrowHeading;

  void _update() {
    final position = _location.position;
    final speed = position?.speed;
    final course = position?.course;
    final walking = _settings.courseWhenWalking &&
        speed != null &&
        course != null &&
        speed.isFinite &&
        course.isFinite &&
        speed >= (_usingCourse ? courseOffBelow : courseOnFrom);
    _usingCourse = walking;
    if (walking) _course = normalizeDegrees(course);
  }

  static double _shortest(double degrees) => (degrees + 540) % 360 - 180;

  void _startEase() {
    _ease?.cancel();
    if (_offset.abs() < 0.5) {
      _offset = 0;
      return;
    }
    _ease = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _offset *= 0.7;
      if (_offset.abs() < 0.5) {
        _offset = 0;
        timer.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ease?.cancel();
    _compass.removeListener(_onSensor);
    _location.removeListener(_onSensor);
    _settings.removeListener(_onSensor);
    super.dispose();
  }
}
