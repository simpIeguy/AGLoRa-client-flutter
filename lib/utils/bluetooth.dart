import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../aglora/aglora.dart';
import '../aglora/data.dart';

StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
StreamSubscription<List<int>>? _valueSubscription;

void startBluetoothListener(BluetoothDevice device) {
  // only one tracker at a time: drop listeners from a previous call
  _connectionSubscription?.cancel();
  _valueSubscription?.cancel();

  _connectionSubscription = device.connectionState.listen((status) async {
    if (status != BluetoothConnectionState.connected) return;
    if (kDebugMode) print('Request history');

    try {
      List<BluetoothService> services = await device.discoverServices();

      BluetoothService? agloraService;
      services.forEach((service) {
        if (service.uuid.toString().startsWith("0000ffa2") ||
            service.uuid.toString().startsWith("0000ffe0") ||
            service.uuid.toString() == "ffe0") {
          agloraService = service;
        }
      });

      if (agloraService != null) {
        var characteristics = agloraService!.characteristics;
        for (BluetoothCharacteristic c in characteristics) {
          if (c.uuid.toString().startsWith("0000ffe1") ||
              c.uuid.toString() == "ffe1") {
            _valueSubscription?.cancel();
            _valueSubscription = c.onValueReceived.listen((value) {
              newDataReceiver(value);
            });
            await c.setNotifyValue(true);

            List<int> request = requestAllTrackers.codeUnits;
            await c.write(request, withoutResponse: true);
          }
        }
      }
    } catch (e) {
      print(e);
    }
  });
}
