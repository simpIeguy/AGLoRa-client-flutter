import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_service.dart';
import '../strings.dart';

/// The phone's location is off: say what it costs and offer Android's
/// settings. Returns true when the question was asked (the location is off),
/// false when there is nothing to ask.
Future<bool> askToEnableLocation(
    BuildContext context, LocationService location) async {
  if (location.problem != LocationProblem.serviceOff) return false;
  final turnOn = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text(S.locationOff),
      content: const Text(S.locationOffHint),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text(S.notNow)),
        FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text(S.turnOn)),
      ],
    ),
  );
  if (turnOn == true) await Geolocator.openLocationSettings();
  return true;
}
