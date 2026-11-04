import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tracker_list.dart';
import '../../data/tracker_status.dart';
import '../../data/tracker_store.dart';
import '../../protocol/tracker_name.dart';
import '../../protocol/tracker_point.dart';
import '../../services/app_services.dart';
import '../format.dart';
import '../names.dart';
import '../screens/tracker_screen.dart';
import '../strings.dart';

/// "БЛА 1 вышел на связь": once per tracker, with a sound and a vibration.
/// Works while the app is open; system notifications are a separate task.
class FirstSignalAlerts extends StatefulWidget {
  const FirstSignalAlerts({
    super.key,
    required this.navigatorKey,
    required this.messengerKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  @override
  State<FirstSignalAlerts> createState() => _FirstSignalAlertsState();
}

class _FirstSignalAlertsState extends State<FirstSignalAlerts> {
  StreamSubscription<FirstSignal>? _subscription;
  AppServices? _services;

  // the last status of every UAV, to notice a change
  final Map<String, TrackerStatus> _statuses = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppScope.of(context);
    _subscription ??= services.store.firstSignals.listen(_onFirstSignal);
    if (_services == null) {
      _services = services;
      services.clock.addListener(_checkLinks);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _services?.clock.removeListener(_checkLinks);
    super.dispose();
  }

  /// every second: a UAV that was answering and now is lost, or is back
  void _checkLinks() {
    final services = _services;
    if (services == null || !mounted) return;
    final list = buildTrackerList(services.store, services.clock.now);
    for (final e in [...list.shown, ...list.archived]) {
      if (!e.isUav || e.isMine || e.status == TrackerStatus.waiting) continue;
      final before = _statuses[e.key];
      _statuses[e.key] = e.status;
      final point = e.latest;
      if (before == null || point == null || !services.settings.lostAlert) {
        continue;
      }
      bool up(TrackerStatus s) =>
          s == TrackerStatus.active || s == TrackerStatus.fading;
      final name = displayName(e.name, alias: e.alias);
      if (up(before) && e.status == TrackerStatus.lost) {
        _banner(S.linkLost(name), point, loud: true);
      } else if (before == TrackerStatus.lost && up(e.status)) {
        _banner(S.linkBack(name), point, loud: false);
      }
    }
  }

  void _onFirstSignal(FirstSignal signal) {
    final point = signal.point;
    final name = displayName(parseTrackerName(point.identifier),
        alias: AppScope.of(context).store.aliasOf(point.identifier));
    _banner(S.cameOnline(name), point, loud: true);
  }

  /// a banner with the tracker's last point; [loud]: a sound and a vibration,
  /// otherwise only a light tap
  void _banner(String title, TrackerPoint point, {required bool loud}) {
    final coordinates = formatCoordinates(point.latitude, point.longitude,
        AppScope.of(context).settings.coordinates);
    final messenger = widget.messengerKey.currentState;
    if (messenger == null) return;

    if (loud) {
      unawaited(HapticFeedback.vibrate());
      unawaited(SystemSound.play(SystemSoundType.alert));
    } else {
      unawaited(HapticFeedback.lightImpact());
    }

    void close() => messenger.hideCurrentMaterialBanner();
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(MaterialBanner(
        leading: const Icon(Icons.notifications_active),
        content: Text('$title\n'
            '$coordinates'),
        actions: [
          TextButton(
            onPressed: () {
              close();
              widget.navigatorKey.currentState?.push(MaterialPageRoute(
                  builder: (_) => TrackerScreen(identifier: point.identifier)));
            },
            child: const Text(S.open),
          ),
          TextButton(
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: coordinates)));
              close();
              messenger.showSnackBar(const SnackBar(content: Text(S.copied)));
            },
            child: const Text(S.copy),
          ),
          TextButton(onPressed: close, child: const Text(S.close)),
        ],
      ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
