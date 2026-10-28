import 'dart:async';

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

  TrackerDataSource? get source => _source;

  void attach(TrackerDataSource source) {
    detach();
    _source = source;
    _chunksSubscription = source.chunks.listen(receive);
    _readySubscription = source.ready.listen((isReady) async {
      if (!isReady) {
        store.setConnectedTracker(null);
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
      case MemoryMessage(:final deviceName):
        if (deviceName != null) store.setConnectedTracker(deviceName);
      case InfoMessage():
        break;
      case null:
        appLog('link: skipped "$text"');
    }
  }
}
