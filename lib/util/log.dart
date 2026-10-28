import 'package:flutter/foundation.dart';

/// the app's only log: debug builds print, release builds stay quiet
void appLog(String message) {
  if (kDebugMode) debugPrint(message);
}
