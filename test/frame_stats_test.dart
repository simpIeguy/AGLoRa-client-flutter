import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/util/frame_stats.dart';
import 'package:tsp_tracker/util/log.dart';

void main() {
  test('ten seconds of frames become one line, idle writes nothing', () {
    final before = AppLog.instance.length;
    final stats = FrameStats();
    final t0 = DateTime(2026, 1, 1, 12);
    stats.add(const Duration(milliseconds: 4), const Duration(milliseconds: 3),
        now: t0);
    stats.add(const Duration(milliseconds: 30), const Duration(milliseconds: 5),
        now: t0.add(const Duration(seconds: 5)));
    expect(AppLog.instance.length, before, reason: 'not yet');
    stats.add(const Duration(milliseconds: 2), const Duration(milliseconds: 2),
        now: t0.add(const Duration(seconds: 11)));
    expect(AppLog.instance.length, before + 1);
    expect(AppLog.instance.text,
        contains('perf: 3 frames, build avg 12.0 max 30.0 ms'));
    expect(AppLog.instance.text, contains('1 over 16 ms'));

    stats.flush();
    expect(AppLog.instance.length, before + 1, reason: 'nothing drawn');
  });
}
