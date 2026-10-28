import 'dart:async';

import '../protocol/protocol.dart';
import '../services/data_source.dart';
import 'demo_scenario.dart';

/// the firmware's BLE notification size (USE_BLE_MTU, esp32-ble.h)
const int demoBleMtu = 20;

/// Plays a scenario instead of a tracker. Like the firmware, it splits every
/// message into MTU pieces, keeps the points of other trackers it "received"
/// and answers the app's requests (AGLORA::getRequest in aglora.cpp).
class DemoDataSource implements TrackerDataSource {
  DemoDataSource(this.scenario, {this.speed = 1});

  final DemoScenario scenario;
  final double speed;

  final _chunks = StreamController<List<int>>.broadcast();
  final _ready = StreamController<bool>.broadcast();

  List<DemoChunk> _playlist = [];
  int _next = 0;
  Timer? _timer;
  DateTime _playbackStart = DateTime.now();
  bool _disposed = false;

  /// points stored in the tracker's memory, by memory index
  final Map<int, String> _storedPoints = {};
  String _sentText = '';

  bool get isFinished => _next >= _playlist.length;

  @override
  Stream<List<int>> get chunks => _chunks.stream;

  @override
  Stream<bool> get ready => _ready.stream;

  /// starts the playback; listeners must be attached before
  void start() {
    _playbackStart = DateTime.now();
    _playlist = shiftScenarioTimes(scenario, _playbackStart, speed: speed);
    _next = 0;
    // the "connection" is up: the app asks for the history
    scheduleMicrotask(() {
      if (!_disposed) _ready.add(true);
    });
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_disposed || isFinished) return;
    final dueAt = _playbackStart
        .add(Duration(milliseconds: _playlist[_next].atMs ~/ speed));
    var wait = dueAt.difference(DateTime.now());
    if (wait.isNegative) wait = Duration.zero;
    _timer = Timer(wait, () {
      _emit(_playlist[_next].text);
      _next++;
      _scheduleNext();
    });
  }

  void _emit(String text) {
    if (_disposed) return;
    for (int i = 0; i < text.length; i += demoBleMtu) {
      final end = (i + demoBleMtu < text.length) ? i + demoBleMtu : text.length;
      _chunks.add(text.substring(i, end).codeUnits);
    }
    _rememberPoints(text);
  }

  /// the firmware keeps only points that have a memory index
  void _rememberPoints(String text) {
    _sentText += text;
    while (true) {
      final start = _sentText.indexOf('${messagePrefix}point');
      if (start < 0) {
        // the prefix itself may be cut between two chunks
        const keep = messagePrefix.length + 'point'.length;
        if (_sentText.length > keep) {
          _sentText = _sentText.substring(_sentText.length - keep);
        }
        return;
      }
      final end = _sentText.indexOf(messageTerminator, start);
      if (end < 0) {
        _sentText = _sentText.substring(start);
        return;
      }
      final stop = end + messageTerminator.length;
      final message = _sentText.substring(start, stop);
      _sentText = _sentText.substring(stop);

      final index = RegExp(r'&index=(\d+)').firstMatch(message);
      if (index != null) _storedPoints[int.parse(index.group(1)!)] = message;
    }
  }

  String _memoryMessage() {
    final count = _storedPoints.length;
    return '${messagePrefix}memory&ver=2.3&crc=ok'
        '&dev_name=${scenario.connectedTracker}&dev_bat=100'
        '&memsize=100&index=$count&overwrite=0$messageTerminator';
  }

  @override
  Future<void> send(String request) async {
    final r = request.trim();
    if (r.startsWith('crc')) {
      _emit(_memoryMessage());
    } else if (r.startsWith('clear')) {
      _storedPoints.clear();
      _emit(_memoryMessage());
    } else if (r.startsWith('all')) {
      _emit(_memoryMessage());
      final indexes = _storedPoints.keys.toList()..sort();
      for (final index in indexes) {
        _emit(_storedPoints[index]!);
      }
    } else if (r.startsWith('id')) {
      final point = _storedPoints[int.tryParse(r.substring(2))];
      if (point != null) _emit(point);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _chunks.close();
    _ready.close();
  }
}
