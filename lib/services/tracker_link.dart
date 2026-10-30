import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/tracker_store.dart';
import '../protocol/message_buffer.dart';
import '../protocol/messages.dart';
import '../protocol/protocol.dart';
import '../util/log.dart';
import 'data_source.dart';

/// Connects one data source to the store: chunks → messages → points.
/// Only one tracker at a time: attaching a source drops the previous one.
class TrackerLink {
  TrackerLink(this.store);

  final TrackerStore store;
  final MessageBuffer _buffer = MessageBuffer();

  TrackerDataSource? _source;
  StreamSubscription<List<int>>? _chunksSubscription;
  StreamSubscription<bool>? _readySubscription;

  /// The tracker's "relay my position" switch; null: no link or old firmware.
  final ValueNotifier<bool?> relayMe = ValueNotifier(null);

  TrackerDataSource? get source => _source;

  /// asks the tracker to switch; the new state comes back in a memory message
  Future<void> setRelayMe(bool on) async => _source?.send(requestRelay(on));

  void attach(TrackerDataSource source) {
    detach();
    _source = source;
    _chunksSubscription = source.chunks.listen(receive);
    _readySubscription = source.ready.listen((isReady) async {
      if (!isReady) {
        store.setConnectedTracker(null);
        relayMe.value = null;
        return;
      }
      appLog('link: request history');
      await source.send(requestAll);
    });
  }

  void detach() {
    _chunksSubscription?.cancel();
    _readySubscription?.cancel();
    _chunksSubscription = null;
    _readySubscription = null;
    _source?.dispose();
    _source = null;
    _buffer.reset();
    // no link: no tracker is "connected" any more
    store.setConnectedTracker(null);
    relayMe.value = null;
  }

  /// one BLE chunk
  void receive(List<int> chunk) {
    for (final message in _buffer.add(chunk)) {
      _handle(message);
    }
  }

  void _handle(String text) {
    final message = parseMessage(text);
    switch (message) {
      case PointMessage(:final point):
        final added = store.addPoint(point);
        appLog('link: point ${point.identifier}${added ? '' : ' (known)'}');
      case NoFixMessage(:final identifier):
        store.heardWithoutFix(identifier);
        appLog('link: $identifier without GPS fix');
      case MemoryMessage(:final deviceName, relayMe: final relay):
        if (deviceName != null) store.setConnectedTracker(deviceName);
        relayMe.value = relay;
      case InfoMessage():
        break;
      case null:
        appLog('link: skipped "$text"');
    }
  }
}
