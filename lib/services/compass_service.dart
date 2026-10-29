import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../util/log.dart';

class CompassReading {
  const CompassReading(this.heading, {this.accuracy});

  /// where the top of the phone points, degrees clockwise from north
  final double heading;

  /// Android's estimate, degrees: 15 high, 30 medium, 45 low; null unknown
  final double? accuracy;
}

/// The phone's compass. With the compass off the arrows take the top of the
/// phone for north.
class CompassService extends ChangeNotifier {
  /// [readings] replaces the phone's sensor in tests
  CompassService({Stream<CompassReading>? readings}) : _readings = readings;

  final Stream<CompassReading>? _readings;
  StreamSubscription<CompassReading>? _subscription;

  CompassReading? _last;
  bool _useCompass = true;

  /// the latest reading, also while the compass is switched off
  CompassReading? get reading => _last;

  bool get useCompass => _useCompass;

  set useCompass(bool value) {
    if (_useCompass == value) return;
    _useCompass = value;
    notifyListeners();
  }

  /// what the arrows turn by: 0 with the compass off or without readings
  double get arrowHeading => _useCompass ? (_last?.heading ?? 0) : 0;

  static Stream<CompassReading>? _phoneReadings() => FlutterCompass.events
      ?.where((e) => e.heading != null)
      .map((e) => CompassReading(e.heading!, accuracy: e.accuracy));

  void start() {
    if (_subscription != null) return;
    try {
      _subscription = (_readings ?? _phoneReadings())?.listen((reading) {
        // an uncalibrated sensor may give "not a number": it turned the map
        // into an error screen ("Infinity or NaN toInt")
        if (!reading.heading.isFinite) return;
        final accuracy = reading.accuracy;
        if (accuracy != null && !accuracy.isFinite) {
          reading = CompassReading(reading.heading);
        }
        _last = reading;
        notifyListeners();
      });
    } catch (e) {
      appLog('compass: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
