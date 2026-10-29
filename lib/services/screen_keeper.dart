import 'package:wakelock_plus/wakelock_plus.dart';

import '../util/log.dart';

/// keeps the phone's screen on (true) or lets it go dark again (false)
typedef ScreenKeeper = Future<void> Function(bool on);

/// the real one; no permission needed, it only flags the app's window
Future<void> keepPhoneScreenOn(bool on) async {
  try {
    await WakelockPlus.toggle(enable: on);
  } catch (e) {
    appLog('screen: $e');
  }
}
