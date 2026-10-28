import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../services/app_services.dart';
import '../../util/log.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/compass_switch.dart';
import '../widgets/tracker_card.dart';

/// The trackers the connected one knows about. [device] is null in the demo.
class TrackersScreen extends StatelessWidget {
  const TrackersScreen({super.key, this.device, this.demoTitle})
      : assert(device != null || demoTitle != null);

  final BluetoothDevice? device;
  final String? demoTitle;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return Scaffold(
      appBar: AppBar(
        title: Text(device?.platformName ?? demoTitle!),
        actions: [if (device != null) _ConnectionActions(device: device!)],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final points = store.latestPoints;
          if (points.isEmpty) {
            return const Center(child: Text(S.noTrackersYet));
          }
          return ListView(children: [
            for (final point in points)
              TrackerCard(key: ValueKey(point.identifier), point: point),
          ]);
        },
      ),
      bottomNavigationBar: const BottomAppBar(child: CompassSwitch()),
    );
  }
}

class _ConnectionActions extends StatelessWidget {
  const _ConnectionActions({required this.device});

  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    final onBar = Theme.of(context).appBarTheme.foregroundColor;
    return StreamBuilder<BluetoothConnectionState>(
      stream: device.connectionState,
      initialData: BluetoothConnectionState.disconnected,
      builder: (context, snapshot) {
        final connected = snapshot.data == BluetoothConnectionState.connected;
        return Row(children: [
          OutlinedButton(
            onPressed: connected
                ? () => device.disconnect()
                : () => device.connect().catchError((e) => appLog('ble: $e')),
            style: OutlinedButton.styleFrom(
              foregroundColor: onBar,
              side: BorderSide(color: onBar ?? AppColors.onDark),
            ),
            child: Text(connected ? S.disconnect : S.connect),
          ),
          const SizedBox(width: AppSizes.gap),
          connected
              ? Icon(CupertinoIcons.bluetooth, color: onBar)
              : Icon(Icons.bluetooth_disabled, color: AppColors.lampBad),
          const SizedBox(width: AppSizes.gap),
        ]);
      },
    );
  }
}
