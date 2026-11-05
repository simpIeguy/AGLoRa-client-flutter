import 'dart:async';
import 'dart:io';

/// A map tile that did not come (no network, a slow server) is not a failure
/// of the app. flutter_map then tries a fallback address it does not have and
/// raises a second error, "No host specified in URI"; both come through the
/// image service and must not be counted as a crash.
bool isTileLoadFailure(Object error, String? library) {
  if (library != 'image resource service') return false;
  return error is SocketException ||
      error is HttpException ||
      // package:http is not our own dependency, so the type is read by name
      error.runtimeType.toString() == 'ClientException' ||
      error is TimeoutException ||
      (error is ArgumentError && '$error'.contains('No host specified'));
}
