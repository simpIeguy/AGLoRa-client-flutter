import 'package:flutter/material.dart';

import '../../data/sensor_lamps.dart';
import '../../services/app_services.dart';
import '../strings.dart';
import '../theme.dart';

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
            useCompass: services.compass.useCompass,
            hasReading: reading != null,
            accuracy: reading?.accuracy);

        final accuracy = phone?.accuracy;
        final gpsText = phone == null
            ? S.gpsNone
            : accuracy == null
                ? S.gpsNoAccuracy
                : S.gpsAccuracy(accuracy.round());
        final compassText = !services.compass.useCompass
            ? S.compassOff
            : reading == null
                ? S.compassNone
                : switch (compass) {
                    LampLevel.good => S.compassGood,
                    LampLevel.fair => S.compassFair,
                    _ => S.compassBad,
                  };

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.padding, vertical: AppSizes.gap / 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSizes.padding * 2,
                runSpacing: AppSizes.gap / 2,
                children: [
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

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: AppSizes.lamp,
        height: AppSizes.lamp,
        decoration:
            BoxDecoration(color: AppColors.lamp(level), shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSizes.gap / 2),
      Text(text, style: Theme.of(context).textTheme.titleSmall),
    ]);
  }
}
