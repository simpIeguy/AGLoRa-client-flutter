import 'package:flutter/material.dart';

import '../../data/sensor_lamps.dart';
import '../../services/app_services.dart';
import '../../services/location_service.dart';
import '../strings.dart';
import '../theme.dart';
import 'ask_location.dart';

/// "GPS ±6 м" and "Компас точный" with a colored lamp each
class SensorLamps extends StatelessWidget {
  const SensorLamps({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(
          [services.location, services.compass, services.clock]),
      builder: (context, _) {
        final phone = services.location.position;
        final gps = gpsLamp(
            fixTime: phone?.time,
            accuracy: phone?.accuracy,
            now: services.clock.now);
        final reading = services.compass.reading;
        final compass = compassLamp(
            hasReading: reading != null, accuracy: reading?.accuracy);

        final accuracy = phone?.accuracy;
        final gpsText = phone == null
            ? S.gpsNone
            : accuracy == null
                ? S.gpsNoAccuracy
                : S.gpsAccuracy(accuracy.round());
        final compassText = reading == null
            ? S.compassNone
            : switch (compass) {
                LampLevel.good => S.compassGood,
                LampLevel.fair => S.compassFair,
                LampLevel.bad => S.compassBad,
              };

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 0, vertical: AppSizes.gap / 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSizes.padding * 2,
                runSpacing: AppSizes.gap / 2,
                children: [
                  // location off: a tap offers Android's settings
                  if (services.location.problem == LocationProblem.serviceOff)
                    InkWell(
                      onTap: () =>
                          askToEnableLocation(context, services.location),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(minHeight: AppSizes.minTap),
                        child: Align(
                            widthFactor: 1,
                            child: _Lamp(level: gps, text: gpsText)),
                      ),
                    )
                  else
                    _Lamp(level: gps, text: gpsText),
                  _Lamp(level: compass, text: compassText),
                ],
              ),
              if (compass == LampLevel.bad && reading != null)
                const Text(S.figureEight),
            ],
          ),
        );
      },
    );
  }
}

class _Lamp extends StatelessWidget {
  const _Lamp({required this.level, required this.text});

  final LampLevel level;
  final String text;

  /// like the status dots: filled good (green) or fair (amber), an empty
  /// ring bad; the word next to it says which
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final decoration = switch (level) {
      LampLevel.good => BoxDecoration(color: p.green, shape: BoxShape.circle),
      LampLevel.fair => BoxDecoration(color: p.amber, shape: BoxShape.circle),
      LampLevel.bad => BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: p.muted, width: 2)),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: AppSizes.lamp, height: AppSizes.lamp, decoration: decoration),
      const SizedBox(width: AppSizes.gap),
      Text(text,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.muted)),
    ]);
  }
}
