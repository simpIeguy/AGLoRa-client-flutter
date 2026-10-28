import 'dart:async';

import 'package:flutter/foundation.dart';

import 'aglora.dart';
import 'data.dart';
import 'memory.dart';

/// Where the tracker's messages come from: the real BLE link or the demo
/// player. Both feed the same parsing code through [attachDataSource].
abstract class AgloraDataSource {
  /// raw chunks, the way BLE notifications deliver them
  Stream<List<int>> get chunks;

  /// true once requests can be sent, false when the link is lost
  Stream<bool> get ready;

  /// app → tracker request: crc, clear, all, id<N>
  Future<void> send(String request);

  void dispose();
}

AgloraDataSource? activeDataSource;
StreamSubscription<List<int>>? _chunksSubscription;
StreamSubscription<bool>? _readySubscription;

/// only one tracker at a time: the previous source is dropped
void attachDataSource(AgloraDataSource source) {
  detachDataSource();
  activeDataSource = source;

  _chunksSubscription = source.chunks.listen(newDataReceiver);
  _readySubscription = source.ready.listen((isReady) async {
    if (!isReady) {
      agloraAppMemory.setConnectedTracker(null);
      return;
    }
    if (kDebugMode) print('Request history');
    await source.send(requestAllTrackers);
  });
}

void detachDataSource() {
  _chunksSubscription?.cancel();
  _readySubscription?.cancel();
  _chunksSubscription = null;
  _readySubscription = null;
  activeDataSource?.dispose();
  activeDataSource = null;
}
