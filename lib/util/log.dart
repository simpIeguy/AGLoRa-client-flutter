import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// where the journal is kept between launches
abstract class LogBackend {
  Future<String> read();
  Future<void> write(String text);
}

/// a file in the app's own cache folder
class FileLogBackend implements LogBackend {
  FileLogBackend([File? file])
      : _file = file ?? File('${Directory.systemTemp.path}/aglora_journal.txt');

  final File _file;

  @override
  Future<String> read() async {
    if (!await _file.exists()) return '';
    return _file.readAsString();
  }

  @override
  Future<void> write(String text) => _file.writeAsString(text, flush: true);
}

/// Coordinates and long numbers are not for the journal: it is sent to the
/// developer, and a coordinate is the place where a person looks for a UAV.
String maskPlaces(String text) => text
    .replaceAll(RegExp(r'-?\d{1,3}\.\d{4,}'), '#')
    .replaceAll(RegExp(r'\d{6,}'), '#');

/// The journal of the app: the last lines of what happened and every error
/// with its trace. Kept in a file, so it survives a restart; the user saves
/// it from the settings and sends it on. No coordinates in it.
class AppLog {
  AppLog({this.maxLines = 600, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// the journal of the running app
  static final AppLog instance = AppLog();

  /// the line that starts every launch
  static const String launchMark = '== запуск';

  /// the mark of an error line
  static const String errorMark = '!!';

  final int maxLines;
  final DateTime Function() _now;
  final List<String> _lines = [];
  LogBackend? _backend;
  Timer? _flushTimer;

  /// the launch before this one had an error (shown once, then false)
  bool previousRunHadError = false;

  String get text => _lines.isEmpty ? '' : '${_lines.join('\n')}\n';
  int get length => _lines.length;

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _stamp() {
    final t = _now();
    return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
  }

  /// reads the earlier launches and starts a new one; [header]: the version,
  /// the phone
  Future<void> start(LogBackend backend, {required String header}) async {
    _backend = backend;
    final before = List<String>.of(_lines);
    _lines.clear();
    try {
      final old = (await backend.read()).split('\n')
        ..removeWhere((l) => l.isEmpty);
      _lines.addAll(old);
    } catch (_) {
      // an unreadable file is a new journal
    }
    final lastLaunch = _lines.lastIndexWhere((l) => l.startsWith(launchMark));
    previousRunHadError = _lines
        .skip(lastLaunch < 0 ? 0 : lastLaunch)
        .any((l) => l.contains(' $errorMark '));
    final t = _now();
    _lines.add('$launchMark ${t.year}-${_two(t.month)}-${_two(t.day)} '
        '${_stamp()} $header');
    _lines.addAll(before);
    _trim();
    _scheduleFlush();
  }

  void add(String message) {
    final line = '${_stamp()} ${maskPlaces(message).replaceAll('\n', ' | ')}';
    _lines.add(line);
    _trim();
    _scheduleFlush();
  }

  /// an error that nobody caught: with the top of its trace, written at once
  void error(Object error, StackTrace? stack, {String where = ''}) {
    final trace = (stack?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(12);
    add('$errorMark ${where.isEmpty ? '' : '$where: '}$error');
    for (final l in trace) {
      _lines.add('    ${maskPlaces(l.trim())}');
    }
    _trim();
    unawaited(flush());
  }

  void _trim() {
    if (_lines.length > maxLines) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
  }

  void _scheduleFlush() {
    if (_backend == null || (_flushTimer?.isActive ?? false)) return;
    _flushTimer = Timer(const Duration(seconds: 3), () => unawaited(flush()));
  }

  /// to the file at once: the app goes to the background
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    try {
      await _backend?.write(text);
    } catch (_) {
      // the journal must never bring the app down
    }
  }

  Future<void> clear() async {
    _lines.clear();
    previousRunHadError = false;
    await flush();
  }
}

/// the app's log: debug builds print too; every line goes to the journal
void appLog(String message) {
  if (kDebugMode) debugPrint(message);
  AppLog.instance.add(message);
}
