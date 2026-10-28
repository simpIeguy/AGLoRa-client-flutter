import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../strings.dart';
import 'demo_screens.dart';

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({super.key, this.state});

  final BluetoothAdapterState? state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.appName,
                style: textTheme.headlineMedium
                    ?.copyWith(color: scheme.onPrimary)),
            const SizedBox(height: 30),
            Icon(Icons.bluetooth_disabled,
                size: 100.0, color: scheme.onPrimary.withValues(alpha: 0.6)),
            const SizedBox(height: 30),
            Text(S.bluetoothState(state?.name),
                style: textTheme.titleSmall?.copyWith(color: scheme.onPrimary)),
            // the demo works without Bluetooth (debug builds only)
            DemoModeButton(color: scheme.onPrimary),
          ],
        ),
      ),
    );
  }
}
