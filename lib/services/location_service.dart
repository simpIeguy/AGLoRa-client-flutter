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
}

/// why there is no phone position
enum LocationProblem { none, starting, serviceOff, noPermission, error }

/// The phone's own position, shared by all screens.
class LocationService extends ChangeNotifier {
  /// [positions] replaces the phone's GPS in tests
  LocationService({Stream<PhonePosition>? positions}) : _positions = positions;

  final Stream<PhonePosition>? _positions;
  StreamSubscription<PhonePosition>? _subscription;

  PhonePosition? _position;
  LocationProblem _problem = LocationProblem.starting;

  PhonePosition? get position => _position;
  LocationProblem get problem => _problem;

  Future<void> start() async {
    if (_subscription != null) return;
    final positions = _positions ?? await _phonePositions();
    if (positions == null) return;
    _subscription = positions.listen((position) {
      _position = position;
      _problem = LocationProblem.none;
      notifyListeners();
    }, onError: (Object e) {
      appLog('location: $e');
      _setProblem(e is LocationServiceDisabledException
          ? LocationProblem.serviceOff
          : LocationProblem.error);
    });
  }

  void _setProblem(LocationProblem problem) {
    if (_problem == problem) return;
    _problem = problem;
    notifyListeners();
  }

  Future<Stream<PhonePosition>?> _phonePositions() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setProblem(LocationProblem.noPermission);
        return null;
      }
      return Geolocator.getPositionStream().map(_fromGeolocator);
    } catch (e) {
      appLog('location: $e');
      _setProblem(LocationProblem.error);
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
      );

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
