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

/// The phone's compass. Without readings the arrows take the top of the
/// phone for north (and say they are not to be trusted).
/// degrees of turn below which a new reading is ignored
const double compassMinStep = 1;

class CompassService extends ChangeNotifier {
  /// [readings] replaces the phone's sensor in tests
  CompassService({Stream<CompassReading>? readings}) : _readings = readings;

  final Stream<CompassReading>? _readings;
  StreamSubscription<CompassReading>? _subscription;

  CompassReading? _last;

  /// the latest reading; null until the sensor speaks
  CompassReading? get reading => _last;

  /// what the arrows turn by: 0 without readings
  double get arrowHeading => _last?.heading ?? 0;

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
        // the sensor speaks dozens of times a second; a change under a
        // degree is not worth redrawing the map and the cards
        final last = _last;
        if (last != null &&
            last.accuracy == reading.accuracy &&
            ((reading.heading - last.heading + 540) % 360 - 180).abs() <
                compassMinStep) {
          return;
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
