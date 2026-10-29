import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../data/tracker_list.dart';
import '../../protocol/tracker_name.dart';
import '../../services/app_services.dart';
import '../../util/log.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/sensor_lamps.dart';
import '../widgets/tracker_card.dart';
import '../widgets/who_to_show_sheet.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'wait_tracker_screen.dart';

/// The main screen (the Main mockup): the phone's GPS and compass, "you"
/// (the tracker the phone is connected to), then the UAVs, the people and
/// the others. [device] is null in the demo.
class TrackersScreen extends StatelessWidget {
  const TrackersScreen({super.key, this.device, this.demoTitle})
      : assert(device != null || demoTitle != null);

  final BluetoothDevice? device;
  final String? demoTitle;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _Header(title: demoTitle ?? S.appName),
          Expanded(
            child: ListenableBuilder(
              // the clock moves trackers between the groups
              listenable: Listenable.merge([services.store, services.clock]),
              builder: (context, _) => _list(context,
                  buildTrackerList(services.store, services.clock.now)),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: const _BottomBar(),
    );
  }

  Widget _list(BuildContext context, TrackerList list) {
    final store = AppScope.of(context).store;
    final mine = store.connectedTracker;
    // the connected tracker is "you" at the top, not in the groups
    final shown = [
      for (final e in list.shown)
        if (mine == null || !store.isConnected(e.key)) e
    ];
    List<TrackerEntry> of(TrackerRole role) => [
          for (final e in shown)
            if (e.name.role == role) e
        ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 0,
          AppSizes.screenPadding, AppSizes.screenPadding),
      children: [
        _OwnTracker(device: device),
        if (shown.isEmpty && list.archived.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSizes.screenPadding * 2),
            child: Center(child: Text(S.noTrackersYet)),
          ),
        ..._group(context, S.groupUavs, of(TrackerRole.uav)),
        ..._group(context, S.groupPeople, of(TrackerRole.ground)),
        ..._group(context, S.groupOthers, of(TrackerRole.other)),
        if (list.hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Text(S.hiddenCount(list.hiddenCount)),
          ),
        if (list.archived.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(S.archive(list.archived.length)),
            children: [
              for (final entry in list.archived) _card(entry),
            ],
          ),
      ],
    );
  }

  static List<Widget> _group(
      BuildContext context, String title, List<TrackerEntry> entries) {
    if (entries.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, AppSizes.padding, 4, 0),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: AppPalette.of(context).muted)),
      ),
      for (final entry in entries) _card(entry),
    ];
  }

  static Widget _card(TrackerEntry entry) => Padding(
        key: ValueKey(entry.key),
        padding: const EdgeInsets.only(top: AppSizes.gap),
        child: TrackerCard(entry: entry),
      );
}

/// the app's name, the map and the settings; the phone's GPS and compass
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding, AppSizes.gap, AppSizes.gap, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              tooltip: S.map,
              icon: const Icon(Icons.map_outlined),
              onPressed: () => _openMap(context),
            ),
            IconButton(
              tooltip: S.settings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ]),
          const SensorLamps(),
        ],
      ),
    );
  }

  /// centred on the phone, else on the freshest tracker, else on Minsk
  static void _openMap(BuildContext context) {
    final services = AppScope.of(context);
    final phone = services.location.position;
    final points = services.store.latestPoints
      ..sort((a, b) => b.time.compareTo(a.time));
    final latitude = phone?.latitude ?? points.firstOrNull?.latitude ?? 53.9;
    final longitude =
        phone?.longitude ?? points.firstOrNull?.longitude ?? 27.56;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            MapScreen(centerLatitude: latitude, centerLongitude: longitude)));
  }
}

/// "Вы · GROUND1": the tracker the phone is connected to, and the button to
/// let it go
class _OwnTracker extends StatelessWidget {
  const _OwnTracker({required this.device});

  final BluetoothDevice? device;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final store = AppScope.of(context).store;
    final name = store.connectedTracker ?? device?.platformName ?? '';
    final searching = name.isNotEmpty && store.isSearchingSatellites(name);
    final textTheme = Theme.of(context).textTheme;

    Widget card(bool connected, Widget? button) => Container(
          margin: const EdgeInsets.only(top: AppSizes.padding),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding, AppSizes.gap, AppSizes.gap, AppSizes.gap),
          decoration: BoxDecoration(
            color: p.card,
            border: Border.all(color: p.line),
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: '${S.you} · '),
                      TextSpan(
                          text: name,
                          style: const TextStyle(fontFamily: AppText.mono)),
                    ]),
                    style: textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                      connected
                          ? searching
                              ? '${S.connectedByBluetooth} · ${S.searchingSatellites}'
                              : S.connectedByBluetooth
                          : S.noBluetoothLink,
                      style: textTheme.bodyMedium?.copyWith(color: p.muted)),
                ],
              ),
            ),
            if (button != null) button,
          ]),
        );

    final d = device;
    if (d == null) return card(true, null); // the demo: always connected
    return StreamBuilder<BluetoothConnectionState>(
      stream: d.connectionState,
      initialData: BluetoothConnectionState.disconnected,
      builder: (context, snapshot) {
        final connected = snapshot.data == BluetoothConnectionState.connected;
        return card(
          connected,
          OutlinedButton(
            onPressed: connected
                // let this tracker go and back to the search: another one
                // can be picked there
                ? () {
                    d.disconnect().catchError((e) => appLog('ble: $e'));
                    AppScope.of(context).link.detach();
                    Navigator.of(context).maybePop();
                  }
                : () => d.connect().catchError((e) => appLog('ble: $e')),
            child: Text(connected ? S.disconnectMe : S.connectMe),
          ),
        );
      },
    );
  }
}

/// "Ждать трекер" and "Кого показывать", within reach of the thumb
class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
          color: p.background, border: Border(top: BorderSide(color: p.line))),
      padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding,
          AppSizes.padding, AppSizes.screenPadding, AppSizes.padding),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.bigButton)),
              icon: const Icon(Icons.add),
              label: const Text(S.waitTracker),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WaitTrackerScreen())),
            ),
          ),
          const SizedBox(width: AppSizes.gap),
          SizedBox.square(
            dimension: AppSizes.bigButton,
            child: Tooltip(
              message: S.whoToShow,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => showWhoToShowSheet(context),
                child: Icon(Icons.filter_list,
                    semanticLabel: S.whoToShow, color: p.ink),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
