import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tsp_tracker/services/location_service.dart';

void main() {
  _serviceTests();
  const fix = PhonePosition(latitude: 53.9, longitude: 27.5, accuracy: 6);

  test('location allowed later: picked up on retry, without a restart',
      () async {
    var allowed = false;
    final positions = StreamController<PhonePosition>();
    addTearDown(positions.close);
    final location = LocationService(open: (setProblem) async {
      if (allowed) return positions.stream;
      setProblem(LocationProblem.noPermission);
      return null;
    });

    await location.start();
    expect(location.problem, LocationProblem.noPermission);

    allowed = true; // the user allowed it in the dialog or the settings
    await location.retry();
    positions.add(fix);
    await Future<void>.delayed(Duration.zero);
    expect(location.problem, LocationProblem.none);
    expect(location.position?.accuracy, 6);
  });

  test('a retry while working does not open the GPS twice', () async {
    var opened = 0;
    final location = LocationService(open: (_) async {
      opened++;
      return StreamController<PhonePosition>().stream;
    });
    await location.start();
    await location.retry();
    await location.retry();
    expect(opened, 1);
  });

  test('location switched off: the reason, then it opens again', () async {
    final first = StreamController<PhonePosition>();
    final second = StreamController<PhonePosition>();
    addTearDown(first.close);
    addTearDown(second.close);
    final streams = [first, second];
    final location =
        LocationService(open: (_) async => streams.removeAt(0).stream);

    await location.start();
    first.addError(const LocationServiceDisabledException());
    await Future<void>.delayed(Duration.zero);
    expect(location.problem, LocationProblem.serviceOff);

    await location.retry(); // switched on, back in the app
    second.add(fix);
    await Future<void>.delayed(Duration.zero);
    expect(location.problem, LocationProblem.none);
  });
}

void _serviceTests() {
  test('location switched off: the old position goes, on: opened again',
      () async {
    final enabled = StreamController<bool>();
    final streams = [StreamController<PhonePosition>()];
    addTearDown(enabled.close);
    final location = LocationService(
        open: (_) async => streams.last.stream, serviceEnabled: enabled.stream);
    await location.start();
    streams.last.add(const PhonePosition(latitude: 53.9, longitude: 27.5));
    await Future<void>.delayed(Duration.zero);
    expect(location.position, isNotNull);

    enabled.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(location.problem, LocationProblem.serviceOff);
    expect(location.position, isNull,
        reason: 'a stale position would point the arrows wrong');

    streams.add(StreamController<PhonePosition>());
    enabled.add(true);
    await Future<void>.delayed(Duration.zero);
    streams.last.add(const PhonePosition(latitude: 53.91, longitude: 27.5));
    await Future<void>.delayed(Duration.zero);
    expect(location.problem, LocationProblem.none);
    expect(location.position?.latitude, 53.91);
  });
}
