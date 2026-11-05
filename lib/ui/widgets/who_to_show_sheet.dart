import 'package:flutter/material.dart';

import '../../data/tracker_list.dart';
import '../../data/tracker_status.dart';
import '../../services/app_services.dart';
import '../names.dart';
import '../strings.dart';
import 'app_sheet.dart';
import 'tracker_card.dart';

Future<void> showWhoToShowSheet(BuildContext context) => showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    // with many trackers the list used to fill the whole screen: nothing to
    // tap beside it, and a pull down only scrolled the list
    maxHeightFraction: 0.75,
    builder: (_) => const _WhoToShowSheet());

/// Ticks per tracker. UAVs are always on and can not be unticked, so a UAV
/// is never hidden by mistake; the connected tracker is always shown too.
/// The title with "Скрыть все" / "Показать все" and the controls below stay
/// in place, only the trackers scroll between them.
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
        final switchable = [
          for (final e in entries)
            if (!_locked(e)) e.key
        ];
        final anyShown = switchable.any((k) => !store.isHidden(k));
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(S.whoToShow,
                    style: Theme.of(context).textTheme.titleLarge),
                subtitle: const Text(
                    '${S.uavsAlwaysShown}, ${S.connectedAlwaysShown}'),
                trailing: switchable.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () =>
                            store.setHiddenAll(switchable, anyShown),
                        child: Text(anyShown ? S.hideAll : S.showAll)),
              ),
              const Divider(height: 1),
              Flexible(
                child: Scrollbar(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: [
                      for (final entry in entries)
                        CheckboxListTile(
                          secondary: Icon(roleIcon(entry.name.role)),
                          title: Text(displayName(entry.name,
                              alias: entry.alias, mine: entry.isMine)),
                          subtitle: Text(entry.name.raw),
                          value: !store.isHidden(entry.key) || _locked(entry),
                          onChanged: _locked(entry)
                              ? null
                              : (shown) =>
                                  store.setHidden(entry.key, shown == false),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
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
