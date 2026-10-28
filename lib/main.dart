import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'screens/screen_bluetooth_off.dart';
import 'screens/screen_find_devices.dart';
import 'utils/compass.dart';

void main() {
  runApp(AGLoRaApp());
}

class AGLoRaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<BluetoothAdapterState>(
          stream: FlutterBluePlus.adapterState,
          initialData: BluetoothAdapterState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothAdapterState.on) {
              startCompassListener();
              return FindDevicesScreen();
            }
            //return DeviceDemoScreen();
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}
