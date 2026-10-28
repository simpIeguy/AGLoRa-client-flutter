import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/app_services.dart';
import '../strings.dart';

/// "Компас телефона" on/off for the arrows on the cards
class CompassSwitch extends StatelessWidget {
  const CompassSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final compass = AppScope.of(context).compass;
    final color = Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: compass,
      builder: (context, _) => MergeSemantics(
        child: ListTile(
          leading: Transform.rotate(
            angle: -2 * pi * (compass.arrowHeading + 45) / 360,
            child: Icon(CupertinoIcons.compass, size: 35, color: color),
          ),
          title: const Text(S.useCompass),
          trailing: Switch(
            value: compass.useCompass,
            onChanged: (value) => compass.useCompass = value,
          ),
          onTap: () => compass.useCompass = !compass.useCompass,
        ),
      ),
    );
  }
}
