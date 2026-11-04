import 'dart:ui';

import 'log.dart';

/// How fast the screen is drawn, as one line in the journal every ten
/// seconds while something is drawn: the number of frames, the average and
/// the worst time of building (our code) and rasterizing (the picture), and
/// how many frames took longer than the 16 ms of 60 per second.
/// Idle seconds, with nothing drawn, write nothing.
class FrameStats {
  FrameStats({this.every = const Duration(seconds: 10)});

  final Duration every;

  int _frames = 0;
  int _slow = 0;
  int _buildSum = 0;
  int _buildMax = 0;
  int _rasterSum = 0;
  int _rasterMax = 0;
  DateTime? _since;

  void onTimings(List<FrameTiming> timings, {DateTime? now}) {
    for (final t in timings) {
      add(t.buildDuration, t.rasterDuration, now: now);
    }
  }

  void add(Duration build, Duration raster, {DateTime? now}) {
    final at = now ?? DateTime.now();
    _since ??= at;
    _frames++;
    final b = build.inMicroseconds, r = raster.inMicroseconds;
    _buildSum += b;
    _rasterSum += r;
    if (b > _buildMax) _buildMax = b;
    if (r > _rasterMax) _rasterMax = r;
    if (b > 16000 || r > 16000) _slow++;
    if (at.difference(_since!) >= every) flush(now: at);
  }

  double _ms(int micro) => micro / 1000;

  void flush({DateTime? now}) {
    if (_frames > 0) {
      appLog('perf: $_frames frames, '
          'build avg ${_ms(_buildSum ~/ _frames).toStringAsFixed(1)} '
          'max ${_ms(_buildMax).toStringAsFixed(1)} ms, '
          'raster avg ${_ms(_rasterSum ~/ _frames).toStringAsFixed(1)} '
          'max ${_ms(_rasterMax).toStringAsFixed(1)} ms, '
          '$_slow over 16 ms');
    }
    _frames = _slow = _buildSum = _buildMax = _rasterSum = _rasterMax = 0;
    _since = null;
  }
}
