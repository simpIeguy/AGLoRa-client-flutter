import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/ui/format.dart';
import 'package:tsp_tracker/util/geo.dart';

/// "Infinity or NaN toInt" turned the map into a red error screen on the
/// phone: "not a number" must stop where it comes in
void main() {
  test('a compass reading that is not a number is dropped', () async {
    final compass = CompassService(
        readings: Stream.fromIterable(const [
      CompassReading(30, accuracy: 15),
      CompassReading(double.nan, accuracy: 15),
      CompassReading(40, accuracy: double.nan),
    ]))
      ..start();
    final headings = <double>[];
    compass.addListener(() => headings.add(compass.reading!.heading));
    await Future<void>.delayed(Duration.zero);
    expect(headings, [30, 40]);
    expect(compass.reading!.accuracy, isNull);
  });

  test('a turn under a degree is not worth a redraw', () async {
    final compass = CompassService(
        readings: Stream.fromIterable(const [
      CompassReading(30, accuracy: 15),
      CompassReading(30.4, accuracy: 15),
      CompassReading(31.2, accuracy: 15),
      CompassReading(359.5, accuracy: 15),
      CompassReading(0.2, accuracy: 15),
    ]))
      ..start();
    final headings = <double>[];
    compass.addListener(() => headings.add(compass.reading!.heading));
    await Future<void>.delayed(Duration.zero);
    expect(headings, [30, 31.2, 359.5]);
  });

  test('a distance that is not a number shows a dash', () {
    expect(distanceParts(double.nan), (value: '—', unit: 'м'));
    expect(formatDistance(double.infinity), '— м');
  });

  test('two points a few metres apart, or the same one', () {
    expect(distanceBetween(53.92753, 27.66763, 53.92753, 27.66763), 0);
    final d = distanceBetween(53.92753, 27.66763, 53.92778, 27.66763);
    expect(d, closeTo(28, 1));
  });
}
