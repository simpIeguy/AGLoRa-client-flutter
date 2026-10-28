import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../data/tracker_list.dart';
import '../../services/app_services.dart';
import '../../util/log.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/compass_switch.dart';
import '../widgets/sensor_lamps.dart';
import '../widgets/tracker_card.dart';
import '../widgets/wait_tracker_dialog.dart';
import '../widgets/who_to_show_sheet.dart';

/// The trackers the connected one knows about. [device] is null in the demo.
class TrackersScreen extends StatelessWidget {
  const TrackersScreen({super.key, this.device, this.demoTitle})
      : assert(device != null || demoTitle != null);

  final BluetoothDevice? device;
  final String? demoTitle;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(device?.platformName ?? demoTitle!),
        actions: [
          IconButton(
            tooltip: S.whoToShow,
            icon: const Icon(Icons.filter_list),
            onPressed: () => showWhoToShowSheet(context),
          ),
          if (device != null) _ConnectionActions(device: device!),
        ],
      ),
      body: Column(children: [
        const SensorLamps(),
        Expanded(
          child: ListenableBuilder(
            // the clock moves trackers between the groups
            listenable: Listenable.merge([services.store, services.clock]),
            builder: (context, _) =>
                _list(buildTrackerList(services.store, services.clock.now)),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_alert),
        label: const Text(S.waitTracker),
        onPressed: () => showWaitTrackerDialog(context),
      ),
      bottomNavigationBar: const BottomAppBar(child: CompassSwitch()),
    );
  }

  Widget _list(TrackerList list) {
    if (list.shown.isEmpty && list.archived.isEmpty) {
      return const Center(child: Text(S.noTrackersYet));
    }
    return ListView(
      // room for the floating button under the last card
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final entry in list.shown)
          TrackerCard(key: ValueKey(entry.key), entry: entry),
        if (list.hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Text(S.hiddenCount(list.hiddenCount)),
          ),
        if (list.archived.isNotEmpty)
          ExpansionTile(
            title: Text(S.archive(list.archived.length)),
            children: [
              for (final entry in list.archived)
                TrackerCard(key: ValueKey(entry.key), entry: entry),
            ],
          ),
      ],
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
