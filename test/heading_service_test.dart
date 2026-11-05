import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/services/app_settings.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/heading_service.dart';
import 'package:tsp_tracker/services/location_service.dart';

void main() {
  late StreamController<PhonePosition> positions;
  late StreamController<CompassReading> readings;
  late AppSettings settings;
  late LocationService location;
  late CompassService compass;
  late HeadingService heading;

  setUp(() async {
    positions = StreamController<PhonePosition>.broadcast();
    readings = StreamController<CompassReading>.broadcast();
    settings = AppSettings();
    location = LocationService(positions: positions.stream);
    compass = CompassService(readings: readings.stream);
    heading = HeadingService(compass, location, settings);
    await location.start();
    compass.start();
  });

  tearDown(() {
    heading.dispose();
    compass.dispose();
    location.dispose();
    positions.close();
    readings.close();
  });

  Future<void> move(double speed, double course) async {
    positions.add(PhonePosition(
        latitude: 55, longitude: 37, speed: speed, course: course));
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> point(double degrees) async {
    readings.add(CompassReading(degrees));
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> settle() => Future<void>.delayed(const Duration(seconds: 1));

  test('by default the compass, even when walking', () async {
    await point(90);
    await move(1.5, 200);
    expect(heading.usingCourse, isFalse);
    expect(heading.arrowHeading, 90);
  });

  test('setting on and walking: the GPS course', () async {
    settings.courseWhenWalking = true;
    await point(90);
    await move(1.5, 200);
    await settle();
    expect(heading.usingCourse, isTrue);
    expect(heading.arrowHeading, closeTo(200, 0.5));
  });

  test('standing still goes back to the compass', () async {
    settings.courseWhenWalking = true;
    await point(90);
    await move(1.5, 200);
    await move(0.2, 10);
    await settle();
    expect(heading.usingCourse, isFalse);
    expect(heading.arrowHeading, closeTo(90, 0.5));
  });

  test('hysteresis: between 0.6 and 1.0 keeps what it was', () async {
    settings.courseWhenWalking = true;
    await point(90);
    await move(0.8, 200);
    expect(heading.usingCourse, isFalse, reason: 'not yet walking');
    await move(1.2, 200);
    expect(heading.usingCourse, isTrue);
    await move(0.8, 210);
    expect(heading.usingCourse, isTrue, reason: 'still walking');
    await move(0.5, 210);
    expect(heading.usingCourse, isFalse);
  });

  test('the switch is eased, the shortest way round north', () async {
    settings.courseWhenWalking = true;
    await point(350);
    await move(1.5, 10);
    // right after the switch the arrow is still near where it was (350)
    expect(heading.arrowHeading, closeTo(350, 1));
    await settle();
    expect(heading.arrowHeading, closeTo(10, 0.5));
  });

  test('no speed or no course: the compass', () async {
    settings.courseWhenWalking = true;
    await point(90);
    positions.add(const PhonePosition(latitude: 55, longitude: 37));
    await Future<void>.delayed(Duration.zero);
    expect(heading.usingCourse, isFalse);
  });
}
