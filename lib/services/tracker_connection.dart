import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../util/log.dart';
import 'app_settings.dart';
import 'ble_data_source.dart';
import 'tracker_link.dart';

/// The phone's own tracker over Bluetooth. It is remembered: after a launch
/// the app connects to it again by itself, and when it goes out of range
/// Android connects again once it is back. "Отключиться" forgets it.
class TrackerConnection extends ChangeNotifier {
  TrackerConnection(this.link, this.settings);

  final TrackerLink link;
  final AppSettings settings;

  BluetoothDevice? _device;
  BluetoothConnectionState _state = BluetoothConnectionState.disconnected;
  BluetoothAdapterState _adapter = BluetoothAdapterState.unknown;

  /// the user wants to stay connected: after a drop, connect again
  bool _wanted = false;
  bool _reconnecting = false;

  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;

  BluetoothAdapterState get adapter => _adapter;

  bool get isConnected =>
      _device != null && _state == BluetoothConnectionState.connected;

  /// wanted, but not there yet (or out of range for now)
  bool get isConnecting => _wanted && !isConnected;

  /// as the tracker calls itself; the remembered name until it answers
  String get name {
    final n = _device?.platformName ?? '';
    return n.isNotEmpty ? n : (settings.lastTracker?.name ?? '');
  }

  /// follows Bluetooth; once it is on, the remembered tracker is connected
  void start() {
    _adapterSubscription ??= FlutterBluePlus.adapterState.listen((state) {
      _adapter = state;
      notifyListeners();
      if (state == BluetoothAdapterState.on && _device == null) {
        unawaited(_reconnectLast());
      }
    });
  }

  Future<void> _reconnectLast() async {
    final last = settings.lastTracker;
    if (last == null) return;
    appLog('ble: back to ${last.name}');
    await connectTo(BluetoothDevice.fromId(last.id));
  }

  /// from the list of found devices, or the remembered one
  Future<void> connectTo(BluetoothDevice device) async {
    await _drop();
    _device = device;
    _wanted = true;
    final name = device.platformName.isNotEmpty
        ? device.platformName
        : settings.lastTracker?.name ?? '';
    settings.lastTracker = (id: device.remoteId.str, name: name);
    // services are discovered by the data source once connected
    link.attach(BleDataSource(device));
    _stateSubscription = device.connectionState.listen(_onState);
    notifyListeners();
    try {
      await device.connect(timeout: const Duration(seconds: 15));
    } catch (e) {
      appLog('ble: $e');
      // not near yet: Android connects once it is in range
      _connectWhenInRange();
    }
  }

  void _onState(BluetoothConnectionState state) {
    // the stream starts with "disconnected" before the first try: only a
    // drop after a real connection means "out of range"
    final dropped = _state == BluetoothConnectionState.connected &&
        state == BluetoothConnectionState.disconnected;
    _state = state;
    if (state == BluetoothConnectionState.connected) _reconnecting = false;
    notifyListeners();
    if (dropped && _wanted) _connectWhenInRange();
  }

  void _connectWhenInRange() {
    final device = _device;
    if (device == null || _reconnecting || !_wanted) return;
    _reconnecting = true;
    device
        .connect(autoConnect: true, mtu: null)
        .catchError((Object e) => appLog('ble: $e'));
  }

  /// after the demo, which took the link for its made-up trackers
  void reattach() {
    final device = _device;
    if (device != null) link.attach(BleDataSource(device));
  }

  /// "Отключиться": let the tracker go and forget it
  Future<void> disconnect() async {
    _wanted = false;
    settings.lastTracker = null;
    await _drop();
  }

  Future<void> _drop() async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    final device = _device;
    _device = null;
    _reconnecting = false;
    _state = BluetoothConnectionState.disconnected;
    link.detach();
    notifyListeners();
    await device?.disconnect().catchError((Object e) => appLog('ble: $e'));
  }

  @override
  void dispose() {
    _adapterSubscription?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }
}
