import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/app_services.dart';
import '../../services/location_service.dart';
import '../../util/log.dart';
import '../strings.dart';
import 'bluetooth_off_screen.dart';
import 'find_devices_screen.dart';
import 'permissions_screen.dart';

/// which of the entry screens to show
enum EntryStep { permissions, bluetoothOff, scan }

/// Permissions first: without them neither the scan nor the arrow work.
/// Then Bluetooth must be on.
EntryStep entryStep(
    {required BluetoothAdapterState bluetooth,
    required LocationProblem location}) {
  if (bluetooth == BluetoothAdapterState.unauthorized ||
      location == LocationProblem.noPermission) {
    return EntryStep.permissions;
  }
  if (bluetooth == BluetoothAdapterState.on) return EntryStep.scan;
  return EntryStep.bluetoothOff;
}

/// The first screen of the app: follows Bluetooth and the permissions and
/// shows the scan, "Bluetooth выключен" or "Нужны разрешения".
class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final location = AppScope.of(context).location;
    return StreamBuilder<BluetoothAdapterState>(
      stream: FlutterBluePlus.adapterState,
      initialData: BluetoothAdapterState.unknown,
      builder: (context, snapshot) => ListenableBuilder(
        listenable: location,
        builder: (context, _) {
          final bluetooth = snapshot.data!;
          return switch (
              entryStep(bluetooth: bluetooth, location: location.problem)) {
            EntryStep.scan => const FindDevicesScreen(),
            EntryStep.bluetoothOff => BluetoothOffScreen(
                title: S.bluetoothState(bluetooth.name),
                onTurnOn: bluetooth == BluetoothAdapterState.unavailable
                    ? null
                    : () => FlutterBluePlus.turnOn()
                        .catchError((Object e) => appLog('ble: $e')),
              ),
            EntryStep.permissions => PermissionsScreen(
                bluetooth: bluetooth != BluetoothAdapterState.unauthorized,
                location: location.problem != LocationProblem.noPermission,
                onAllow: () {
                  location.retry();
                  // the scan is what makes Android ask for Bluetooth
                  FlutterBluePlus.startScan(
                          timeout: const Duration(seconds: 1),
                          androidUsesFineLocation: true)
                      .catchError((Object e) => appLog('ble: $e'));
                },
                onOpenSettings: Geolocator.openAppSettings,
              ),
          };
        },
      ),
    );
  }
}
