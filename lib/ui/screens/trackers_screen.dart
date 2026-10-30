import 'package:flutter/material.dart';

import '../../data/tracker_list.dart';
import '../../protocol/tracker_name.dart';
import '../../services/app_services.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/link_banner.dart';
import '../widgets/sensor_lamps.dart';
import '../widgets/tracker_card.dart';
import '../widgets/who_to_show_sheet.dart';
import 'find_devices_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'wait_tracker_screen.dart';

/// The main screen and the first one (the Main mockup): the phone's GPS and
/// compass, "you" (the tracker the phone is connected to), then the UAVs,
/// the people and the others. Connecting is the button in the top right
/// corner. [demoTitle] in the demo.
class TrackersScreen extends StatelessWidget {
  const TrackersScreen({super.key, this.demoTitle});

  final String? demoTitle;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _Header(title: demoTitle ?? S.appName, demo: demoTitle != null),
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
        _OwnTracker(demo: demoTitle != null),
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
      // a long press picks a card up; it moves inside its own group only
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: true,
        onReorderItem: (from, to) {
          final keys = [for (final e in entries) e.key];
          keys.insert(to, keys.removeAt(from));
          AppScope.of(context).store.setOrder(keys);
        },
        children: [for (final entry in entries) _card(entry)],
      ),
    ];
  }

  static Widget _card(TrackerEntry entry) => Padding(
        key: ValueKey(entry.key),
        padding: const EdgeInsets.only(top: AppSizes.gap),
        child: TrackerCard(entry: entry),
      );
}

/// the app's name, the map, the settings and the connection; the phone's
/// GPS and compass; what keeps Bluetooth from working
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.demo});

  final String title;
  final bool demo;

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
            if (!demo) const ConnectButton(),
          ]),
          const SensorLamps(),
          if (!demo) const LinkBanner(),
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
/// let it go; without one, the button to pick it
class _OwnTracker extends StatelessWidget {
  const _OwnTracker({required this.demo});

  final bool demo;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final services = AppScope.of(context);
    final store = services.store;
    final connection = services.connection;
    final textTheme = Theme.of(context).textTheme;

    Widget card(
            {required String name, required String state, Widget? button}) =>
        Container(
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
                      TextSpan(
                          text: name.isEmpty ? S.noOwnTracker : '${S.you} · '),
                      TextSpan(
                          text: name,
                          style: const TextStyle(fontFamily: AppText.mono)),
                    ]),
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(state,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(color: p.muted)),
                ],
              ),
            ),
            if (button != null) ...[
              const SizedBox(width: AppSizes.gap),
              button,
            ],
          ]),
        );

    String linked(String name) =>
        name.isNotEmpty && store.isSearchingSatellites(name)
            ? '${S.connectedByBluetooth}\n${S.searchingSatellites}'
            : S.connectedByBluetooth;

    // narrow buttons, so that the name and the state fit in one line
    const narrow = ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      minimumSize: WidgetStatePropertyAll(Size(0, 48)),
    );
    final pick = FilledButton(
      style: narrow,
      onPressed: () => openConnectScreen(context),
      child: const Text(S.connectMe),
    );
    // the demo: always connected to its made-up tracker
    if (demo) {
      final name = store.connectedTracker ?? '';
      return card(
          name: name, state: name.isEmpty ? S.noBluetoothLink : linked(name));
    }
    if (connection == null) {
      return card(name: '', state: S.noBluetoothLink, button: pick);
    }
    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        // the name the tracker gives itself in its messages, else its
        // Bluetooth name
        final name = store.connectedTracker ?? connection.name;
        if (connection.isConnected) {
          return card(
            name: name,
            state: linked(name),
            button: OutlinedButton(
              style: narrow,
              onPressed: connection.disconnect,
              child: const Text(S.disconnectMe),
            ),
          );
        }
        if (connection.isConnecting) {
          return card(
            name: name,
            state: S.connectingToOwn,
            button: OutlinedButton(
              style: narrow,
              onPressed: connection.disconnect,
              child: const Text(S.cancel),
            ),
          );
        }
        return card(name: '', state: S.noBluetoothLink, button: pick);
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
