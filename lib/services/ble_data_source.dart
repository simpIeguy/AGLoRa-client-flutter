import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../util/log.dart';
import 'data_source.dart';

/// the tracker's BLE UART characteristic (HM-10 or ESP32 BLE)
class BleDataSource implements TrackerDataSource {
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

  static bool _isUartService(BluetoothService service) {
    final uuid = service.uuid.toString();
    return uuid.startsWith('0000ffa2') ||
        uuid.startsWith('0000ffe0') ||
        uuid == 'ffe0';
  }

  static bool _isUartCharacteristic(BluetoothCharacteristic c) {
    final uuid = c.uuid.toString();
    return uuid.startsWith('0000ffe1') || uuid == 'ffe1';
  }

  Future<void> _onConnectionState(BluetoothConnectionState status) async {
    if (status != BluetoothConnectionState.connected) {
      _characteristic = null;
      _ready.add(false);
      return;
    }

    try {
      final services = await device.discoverServices();
      BluetoothService? uart;
      for (final service in services) {
        if (_isUartService(service)) uart = service;
      }
      if (uart == null) return;

      for (final c in uart.characteristics) {
        if (!_isUartCharacteristic(c)) continue;
        await _valueSubscription?.cancel();
        _valueSubscription = c.onValueReceived.listen(_chunks.add);
        await c.setNotifyValue(true);
        _characteristic = c;
        _ready.add(true); // the app now asks for the history
      }
    } catch (e) {
      appLog('ble: $e');
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
