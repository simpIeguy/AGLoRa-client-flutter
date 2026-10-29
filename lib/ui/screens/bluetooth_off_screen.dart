import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';
import 'demo_screens.dart';

/// "Bluetooth выключен", as in the BtOff mockup. [onTurnOn] asks Android to
/// switch it on; the scan opens by itself once it is on.
class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({super.key, required this.title, this.onTurnOn});

  /// "Bluetooth выключен", "Bluetooth недоступен"…
  final String title;

  /// null where Android can not do it (no Bluetooth on the phone)
  final VoidCallback? onTurnOn;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(S.appName,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                // the demo works without Bluetooth (debug builds only)
                const DemoModeButton(),
              ]),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 112, color: p.muted),
                    const SizedBox(height: AppSizes.screenPadding),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium),
                    const SizedBox(height: AppSizes.screenPadding),
                    Text(S.bluetoothOffHint,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(color: p.muted)),
                  ],
                ),
              ),
              if (onTurnOn != null)
                FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.bigButton)),
                  onPressed: onTurnOn,
                  child: const Text(S.turnOnBluetooth),
                ),
              const SizedBox(height: AppSizes.gap),
            ],
          ),
        ),
      ),
    );
  }
}
