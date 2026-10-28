import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tracker_store.dart';
import '../../protocol/tracker_name.dart';
import '../../services/app_services.dart';
import '../format.dart';
import '../names.dart';
import '../screens/tracker_log_screen.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription ??=
        AppScope.of(context).store.firstSignals.listen(_onFirstSignal);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onFirstSignal(FirstSignal signal) {
    final point = signal.point;
    final store = AppScope.of(context).store;
    final name = displayName(parseTrackerName(point.identifier),
        alias: store.aliasOf(point.identifier));
    final messenger = widget.messengerKey.currentState;
    if (messenger == null) return;

    unawaited(HapticFeedback.vibrate());
    unawaited(SystemSound.play(SystemSoundType.alert));

    void close() => messenger.hideCurrentMaterialBanner();
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(MaterialBanner(
        leading: const Icon(Icons.notifications_active),
        content: Text('${S.cameOnline(name)}\n'
            '${formatCoordinates(point.latitude, point.longitude)}'),
        actions: [
          TextButton(
            onPressed: () {
              close();
              widget.navigatorKey.currentState?.push(MaterialPageRoute(
                  builder: (_) =>
                      TrackerLogScreen(identifier: point.identifier)));
            },
            child: const Text(S.open),
          ),
          TextButton(
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(
                  text: formatCoordinates(point.latitude, point.longitude))));
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
