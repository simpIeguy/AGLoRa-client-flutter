import 'package:flutter/material.dart';

import '../../data/tracker_list.dart';
import '../../data/tracker_status.dart';
import '../../services/app_services.dart';
import '../names.dart';
import '../strings.dart';
import 'tracker_card.dart';

Future<void> showWhoToShowSheet(BuildContext context) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _WhoToShowSheet());

/// Ticks per tracker. UAVs are always on and can not be unticked, so a UAV
/// is never hidden by mistake; the connected tracker is always shown too.
class _WhoToShowSheet extends StatelessWidget {
  const _WhoToShowSheet();

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final entries = _allEntries(services);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(S.whoToShow,
                    style: Theme.of(context).textTheme.titleLarge),
                subtitle: const Text(
                    '${S.uavsAlwaysShown}, ${S.connectedAlwaysShown}'),
              ),
              for (final entry in entries)
                CheckboxListTile(
                  secondary: Icon(roleIcon(entry.name.role)),
                  title: Text(displayName(entry.name, alias: entry.alias)),
                  subtitle: Text(entry.name.raw),
                  value: !store.isHidden(entry.key) || _locked(entry),
                  onChanged: _locked(entry)
                      ? null
                      : (shown) => store.setHidden(entry.key, shown == false),
                ),
              const Divider(),
              SwitchListTile(
                title: const Text(S.alertNewUavs),
                value: store.alertNewUavs,
                onChanged: (value) => store.alertNewUavs = value,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(S.close)),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _locked(TrackerEntry entry) =>
      entry.isUav || entry.status == TrackerStatus.connected;

  /// shown, archived and hidden ones, all in the list order
  static List<TrackerEntry> _allEntries(AppServices services) {
    final list = buildTrackerList(services.store, services.clock.now,
        includeHidden: true);
    return [...list.shown, ...list.archived];
  }
}
