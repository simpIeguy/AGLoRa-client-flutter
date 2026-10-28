import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../services/app_services.dart';
import '../../services/ble_data_source.dart';
import '../../util/log.dart';
import '../strings.dart';
import '../theme.dart';
import 'demo_screens.dart';
import 'trackers_screen.dart';

/// Bluetooth scan: connected trackers on top, found ones below.
class FindDevicesScreen extends StatelessWidget {
  const FindDevicesScreen({super.key});

  static const Duration _scanTime = Duration(seconds: 4);

  // androidUsesFineLocation: Android hides scan results without location
  // permission; the app also needs it for distance and bearing to trackers
  static Future<void> _scan() => FlutterBluePlus.startScan(
      timeout: _scanTime, androidUsesFineLocation: true);

  /// services are discovered by the data source once connected
  static void _open(BuildContext context, BluetoothDevice device,
      {bool connect = false}) {
    AppScope.of(context).link.attach(BleDataSource(device));
    if (connect) device.connect().catchError((e) => appLog('ble: $e'));
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TrackersScreen(device: device)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.findTrackers),
        actions: const [DemoModeButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _scan,
        child: ListView(children: [
          StreamBuilder<List<BluetoothDevice>>(
            stream: Stream.periodic(const Duration(seconds: 2))
                .map((_) => FlutterBluePlus.connectedDevices),
            initialData: const [],
            builder: (context, snapshot) => Column(children: [
              for (final device in snapshot.data!)
                _ConnectedDeviceTile(
                    device: device, onOpen: () => _open(context, device)),
            ]),
          ),
          StreamBuilder<List<ScanResult>>(
            stream: FlutterBluePlus.scanResults,
            initialData: const [],
            builder: (context, snapshot) => Column(children: [
              for (final result in snapshot.data!)
                _ScanResultTile(
                  result: result,
                  onConnect: () => _open(context, result.device, connect: true),
                ),
            ]),
          ),
        ]),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBluePlus.isScanning,
        initialData: false,
        builder: (context, snapshot) => snapshot.data!
            ? FloatingActionButton(
                tooltip: S.stopScan,
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                onPressed: FlutterBluePlus.stopScan,
                child: const Icon(Icons.stop),
              )
            : const FloatingActionButton(
                tooltip: S.startScan,
                onPressed: _scan,
                child: Icon(Icons.search),
              ),
      ),
    );
  }
}

class _ConnectedDeviceTile extends StatelessWidget {
  const _ConnectedDeviceTile({required this.device, required this.onOpen});

  final BluetoothDevice device;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.gps_fixed),
      title: Text(device.platformName),
      subtitle: const Text(S.deviceConnected),
      trailing: StreamBuilder<BluetoothConnectionState>(
        stream: device.connectionState,
        initialData: BluetoothConnectionState.disconnected,
        builder: (context, snapshot) =>
            snapshot.data == BluetoothConnectionState.connected
                ? ElevatedButton(onPressed: onOpen, child: const Text(S.open))
                : const Text(S.connecting),
      ),
    );
  }
}

class _ScanResultTile extends StatelessWidget {
  const _ScanResultTile({required this.result, required this.onConnect});

  final ScanResult result;
  final VoidCallback onConnect;

  static Icon _signalIcon(int rssi) {
    if (rssi >= -80) return const Icon(Icons.signal_cellular_null);
    if (rssi >= -70) return const Icon(Icons.signal_cellular_4_bar);
    return const Icon(Icons.network_cell_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final name = result.device.platformName;
    return ListTile(
      minTileHeight: AppSizes.minTap,
      title: Text(name.isEmpty ? S.unnamedDevice : name,
          overflow: TextOverflow.ellipsis),
      leading: _signalIcon(result.rssi),
      trailing: ElevatedButton(
        onPressed: result.advertisementData.connectable ? onConnect : null,
        child: const Text(S.connect),
      ),
    );
  }
}
