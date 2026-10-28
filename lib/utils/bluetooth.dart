import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../aglora/data_source.dart';

void startBluetoothListener(BluetoothDevice device) {
  attachDataSource(BleDataSource(device));
}

/// the tracker's BLE UART characteristic (HM-10 or ESP32 BLE)
class BleDataSource implements AgloraDataSource {
  BleDataSource(this.device) {
    _connectionSubscription = device.connectionState.listen(_onConnectionState);
  }

  final BluetoothDevice device;

  final _chunks = StreamController<List<int>>.broadcast();
  final _ready = StreamController<bool>.broadcast();

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _valueSubscription;
  BluetoothCharacteristic? _characteristic;

  @override
  Stream<List<int>> get chunks => _chunks.stream;

  @override
  Stream<bool> get ready => _ready.stream;

  Future<void> _onConnectionState(BluetoothConnectionState status) async {
    if (status != BluetoothConnectionState.connected) {
      _characteristic = null;
      _ready.add(false);
      return;
    }

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
            _valueSubscription = c.onValueReceived.listen(_chunks.add);
            await c.setNotifyValue(true);

            _characteristic = c;
            _ready.add(true); // the app now asks for the history
          }
        }
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Future<void> send(String request) async {
    final c = _characteristic;
    if (c == null) return;
    await c.write(request.codeUnits, withoutResponse: true);
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _valueSubscription?.cancel();
    _chunks.close();
    _ready.close();
  }
}
