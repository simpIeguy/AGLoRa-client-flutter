import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'demo/demo_runner.dart';
import 'services/app_services.dart';
import 'ui/screens/bluetooth_off_screen.dart';
import 'ui/screens/demo_screens.dart';
import 'ui/screens/find_devices_screen.dart';
import 'ui/strings.dart';
import 'ui/theme.dart';
import 'ui/widgets/first_signal_alerts.dart';

void main() {
  final services = AppServices()..start();
  runApp(AppScope(services: services, child: TrackerApp()));
}

class TrackerApp extends StatelessWidget {
  TrackerApp({super.key});

  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: S.appName,
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => FirstSignalAlerts(
          navigatorKey: _navigatorKey,
          messengerKey: _messengerKey,
          child: child!),
      home: isDemoRequestedAtLaunch
          // debug builds only: --dart-define=DEMO_SCENARIO=<id> opens the demo
          ? DemoTrackersScreen(
              scenarioId: demoScenarioFromLaunch,
              speed: double.tryParse(demoSpeedFromLaunch) ?? 1)
          : StreamBuilder<BluetoothAdapterState>(
              stream: FlutterBluePlus.adapterState,
              initialData: BluetoothAdapterState.unknown,
              builder: (context, snapshot) {
                final state = snapshot.data;
                if (state == BluetoothAdapterState.on) {
                  return const FindDevicesScreen();
                }
                return BluetoothOffScreen(state: state);
              }),
    );
  }
}
