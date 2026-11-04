import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../util/log.dart';

class PhonePosition {
  const PhonePosition({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    DateTime? time,
    this.satellites,
    this.speed,
    this.course,
  }) : _time = time;

  final double latitude;
  final double longitude;

  /// metres, null when the phone did not say
  final double? accuracy;

  final DateTime? _time;

  /// when the phone got the fix
  DateTime get time => _time ?? DateTime.now();

  /// satellites in view, null when the phone does not report them
  final int? satellites;

  /// metres per second, null when the phone did not say
  final double? speed;

  /// degrees from north the phone moves to, null when the phone did not say
  final double? course;

  /// Slower than this the GPS course is noise: standing still it jumps around.
  static const double walkingSpeed = 1.0;

  /// The course of the walk, or null when standing (or without a course).
  double? get movingCourse {
    final v = speed, c = course;
    if (v == null || c == null || !v.isFinite || !c.isFinite) return null;
    return v >= walkingSpeed ? c % 360 : null;
  }
}

/// why there is no phone position
enum LocationProblem { none, starting, serviceOff, noPermission, error }

/// opens the phone's positions; null with the reason it could not
typedef PositionsOpener = Future<Stream<PhonePosition>?> Function(
    void Function(LocationProblem) setProblem);

/// The phone's own position, shared by all screens.
class LocationService extends ChangeNotifier {
  /// [positions] replaces the phone's GPS in tests, [open] replaces the way
  /// to it (permission included)
  LocationService(
      {Stream<PhonePosition>? positions,
      PositionsOpener? open,
      Stream<bool>? serviceEnabled})
      : _open = open ??
            (positions == null ? _phonePositions : (_) async => positions),
        // only the real phone tells when the user switches the location
        // on or off in the notification shade
        _serviceEnabled = serviceEnabled ??
            (positions == null && open == null ? _phoneServiceStatus() : null);

  final PositionsOpener _open;
  final Stream<bool>? _serviceEnabled;
  StreamSubscription<bool>? _serviceSubscription;
  StreamSubscription<PhonePosition>? _subscription;
  bool _opening = false;

  PhonePosition? _position;
  LocationProblem _problem = LocationProblem.starting;

  PhonePosition? get position => _position;
  LocationProblem get problem => _problem;

  Future<void> start() async {
    _serviceSubscription ??= _serviceEnabled?.listen(_onServiceChanged);
    if (_subscription != null || _opening) return;
    _opening = true;
    final positions = await _open(_setProblem);
    _opening = false;
    if (positions == null) return;
    _subscription = positions.listen((position) {
      _position = position;
      _problem = LocationProblem.none;
      notifyListeners();
    }, onError: (Object e) {
      appLog('location: $e');
      final off = e is LocationServiceDisabledException;
      _setProblem(off ? LocationProblem.serviceOff : LocationProblem.error);
      // location switched off: open it again when the user comes back
      if (off) _stop();
    }, onDone: _stop);
  }

  /// The user switched the phone's location off or on. Off: the old position
  /// is dropped, it would send the arrows the wrong way. On: open again.
  void _onServiceChanged(bool enabled) {
    if (!enabled) {
      _stop();
      _position = null;
      _problem = LocationProblem.serviceOff;
      notifyListeners();
    } else if (_problem == LocationProblem.serviceOff) {
      _problem = LocationProblem.starting;
      notifyListeners();
      start();
    }
  }

  /// Again after a failure: the user may have allowed the location or
  /// switched it on meanwhile. The app calls it when it comes back on screen.
  Future<void> retry() async {
    if (_subscription == null) await start();
  }

  static Stream<bool> _phoneServiceStatus() =>
      Geolocator.getServiceStatusStream()
          .map((status) => status == ServiceStatus.enabled);

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _setProblem(LocationProblem problem) {
    if (_problem == problem) return;
    _problem = problem;
    notifyListeners();
  }

  static Future<Stream<PhonePosition>?> _phonePositions(
      void Function(LocationProblem) setProblem) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setProblem(LocationProblem.noPermission);
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        setProblem(LocationProblem.serviceOff);
        return null;
      }
      return Geolocator.getPositionStream().map(_fromGeolocator);
    } catch (e) {
      appLog('location: $e');
      setProblem(LocationProblem.error);
      return null;
    }
  }

  // satellites: geolocator_android has them (AndroidPosition), but using it
  // needs that package listed in pubspec.yaml, see docs/audit.md
  static PhonePosition _fromGeolocator(Position p) => PhonePosition(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy > 0 ? p.accuracy : null,
        time: p.timestamp,
        // geolocator reports 0 when it has no speed or course
        speed: p.speed > 0 ? p.speed : null,
        course: p.speed > 0 && p.heading >= 0 ? p.heading : null,
      );

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _stop();
    super.dispose();
  }
}
