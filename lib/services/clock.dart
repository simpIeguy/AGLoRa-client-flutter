import 'dart:async';

import 'package:flutter/foundation.dart';

/// Ticks once a second, so ages and colors change without new data.
/// Tests pass their own time and call [tick].
class Clock extends ChangeNotifier {
  Clock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  Timer? _timer;

  DateTime get now => _now();

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void tick() => notifyListeners();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
