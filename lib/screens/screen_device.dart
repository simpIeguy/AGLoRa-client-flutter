import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../aglora/data.dart';
import '../aglora/memory.dart';
import '../utils/saved_parameters.dart';
import 'widgets/widget_lora_tracker_tile.dart';
import 'widgets/widget_use_compass.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, this.device, this.demoTitle})
      : assert(device != null || demoTitle != null),
        super(key: key);

  /// null in the demo mode
  final BluetoothDevice? device;
  final String? demoTitle;

  Widget _buildTrackersTiles(List<AGLORATrackerPoint> _trackersDataList) {
    return Column(
      children: _trackersDataList
          .map((e) => LORAtrackerTile(
              time: e.time,
              lat: e.latitude,
              lon: e.longitude,
              identifier: e.identifier,
              sensors: e.sensors,
              useCompass: useCompass))
          .toList(),
    );
    //return Text('Not AGLORA data.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(device?.name ?? demoTitle!),
          actions: device == null ? [] : _buildConnectionActions(device!),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              StreamBuilder<List<AGLORATrackerPoint>>(
                stream: trackersListStream,
                // points may have come before this screen started listening
                initialData: agloraAppMemory.trackers,
                builder: (c, snapshot) {
                  return _buildTrackersTiles(snapshot.data!);
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: Colors.white,
          child: WidgetUseCompass(),
        ));
  }

  List<Widget> _buildConnectionActions(BluetoothDevice device) {
    return <Widget>[
      StreamBuilder<BluetoothConnectionState>(
        stream: device.connectionState,
        initialData: BluetoothConnectionState.disconnected,
        builder: (c, snapshot) {
          VoidCallback? onPressed;
          String text;
          switch (snapshot.data) {
            case BluetoothConnectionState.connected:
              onPressed = () => device.disconnect();
              text = 'Disconnect';
              break;
            case BluetoothConnectionState.disconnected:
              onPressed = () => device.connect().catchError((e) => print(e));
              text = 'Connect';
              break;
            default:
              onPressed = null;
              text = snapshot.data?.name.toUpperCase() ?? '';
              break;
          }
          return Row(
            children: [
              OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    text,
                    style: Theme.of(c)
                        .primaryTextTheme
                        .labelLarge
                        ?.copyWith(color: Colors.white),
                  )),
              SizedBox(width: 10),
              bluetoothStatusIcon(device: device),
              SizedBox(width: 10),
            ],
          );
        },
      )
    ];
  }
}

class discoveringServicesIcon extends StatelessWidget {
  const discoveringServicesIcon({
    Key? key,
    required this.device,
  }) : super(key: key);

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: device.isDiscoveringServices,
      initialData: false,
      builder: (c, snapshot) => IndexedStack(
        index: snapshot.data! ? 1 : 0,
        children: <Widget>[
          Icon(Icons.account_tree),
          SizedBox(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.grey),
            ),
            width: 18.0,
            height: 18.0,
          ),
        ],
      ),
    );
  }
}

class bluetoothStatusIcon extends StatelessWidget {
  const bluetoothStatusIcon({
    Key? key,
    required this.device,
  }) : super(key: key);

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BluetoothConnectionState>(
      stream: device.connectionState,
      initialData: BluetoothConnectionState.disconnected,
      builder: (c, snapshot) =>
          (snapshot.data == BluetoothConnectionState.connected)
              ? Icon(CupertinoIcons.bluetooth,
                  color: Colors.lightGreenAccent.shade100)
              : Icon(Icons.bluetooth_disabled, color: Colors.redAccent),
    );
  }
}
