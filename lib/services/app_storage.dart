import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/tracker_store.dart';
import '../util/log.dart';
import 'app_settings.dart';

/// where the saved text lives; the phone's in the app, a map in tests
abstract interface class StorageBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// the app's private preferences on the phone (shared_preferences)
class PhoneStorage implements StorageBackend {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _open async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _open).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await _open).setString(key, value);
}

class MemoryStorage implements StorageBackend {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// The memory between launches (plan step 7): the trackers with their last
/// points and the settings are written a moment after they change, and read
/// back when the app starts.
class AppStorage {
  AppStorage(this.store, this.settings,
      {StorageBackend? backend, this.delay = const Duration(seconds: 2)})
      : _backend = backend ?? PhoneStorage();

  final TrackerStore store;
  final AppSettings settings;
  final StorageBackend _backend;

  /// changes come in bursts (the history on connect): one write after them
  final Duration delay;

  static const String trackersKey = 'trackers';
  static const String settingsKey = 'settings';

  Timer? _timer;
  bool _listening = false;
  bool _paused = false;

  /// what was kept, then listens for changes
  Future<void> start() async {
    await _load();
    if (_listening) return;
    _listening = true;
    store.addListener(_changed);
    settings.addListener(_changed);
  }

  Future<void> _load() async {
    try {
      final trackers = await _backend.read(trackersKey);
      if (trackers != null && !store.loadState(jsonDecode(trackers))) {
        appLog('storage: saved trackers not understood, starting empty');
      }
      final saved = await _backend.read(settingsKey);
      if (saved != null) settings.loadState(jsonDecode(saved));
    } catch (e) {
      // damaged text: the app starts empty instead of not starting
      appLog('storage: $e');
    }
  }

  void _changed() {
    if (_paused) return;
    _timer?.cancel();
    _timer = Timer(delay, save);
  }

  /// at once: the app goes to the background, it may be closed there
  Future<void> save() async {
    _timer?.cancel();
    _timer = null;
    if (_paused) return;
    try {
      await _backend.write(trackersKey, jsonEncode(store.saveState()));
      await _backend.write(settingsKey, jsonEncode(settings.saveState()));
    } catch (e) {
      appLog('storage: $e');
    }
  }

  /// the demo's made-up trackers are not kept: nothing is written meanwhile
  Future<void> pause() async {
    await save();
    _paused = true;
  }

  /// after the demo: back to the user's own trackers
  Future<void> resume() async {
    _paused = false;
    await _load();
  }

  void dispose() {
    _timer?.cancel();
    if (_listening) {
      store.removeListener(_changed);
      settings.removeListener(_changed);
    }
  }
}
