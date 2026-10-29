import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/tracker_store.dart';
import 'app_settings.dart';
import 'app_storage.dart';
import 'clock.dart';
import 'compass_service.dart';
import 'location_service.dart';
import 'map_link.dart';
import 'screen_keeper.dart';
import 'tracker_connection.dart';
import 'tracker_link.dart';

/// Everything the screens need, created once in main() and passed down by
/// [AppScope]. Tests build it with fakes.
class AppServices {
  AppServices({
    TrackerStore? store,
    CompassService? compass,
    LocationService? location,
    Clock? clock,
    AppSettings? settings,
    this.openUrl = openExternally,
    this.keepScreenOn = keepPhoneScreenOn,
    StorageBackend? storage,
    bool bluetooth = false,
  })  : settings = settings ?? AppSettings(),
        store = store ?? TrackerStore(),
        compass = compass ?? CompassService(),
        location = location ?? LocationService(),
        clock = clock ?? Clock() {
    link = TrackerLink(this.store);
    this.storage = storage == null
        ? null
        : AppStorage(this.store, this.settings, backend: storage);
    connection = bluetooth ? TrackerConnection(link, this.settings) : null;
  }

  /// the memory between launches; null in tests that do not need it
  late final AppStorage? storage;

  /// the phone's own tracker over Bluetooth; null in tests and the demo
  /// launch (no Bluetooth there)
  late final TrackerConnection? connection;

  final AppSettings settings;
  final TrackerStore store;
  final CompassService compass;
  final LocationService location;
  final Clock clock;
  late final TrackerLink link;

  /// opens links outside the app (map apps)
  final UrlOpener openUrl;

  /// the full screen keeps the phone's screen on
  final ScreenKeeper keepScreenOn;

  AppLifecycleListener? _lifecycle;

  /// what was kept from the last launch, the sensors, the timer and the
  /// remembered tracker
  Future<void> start() async {
    await storage?.start();
    connection?.start();
    compass.start();
    unawaited(location.start());
    clock.start();
    _lifecycle = AppLifecycleListener(
      // back from a permission dialog or the phone's settings: the location
      // may be allowed or switched on now
      onResume: location.retry,
      // in the background Android may close the app without a word
      onPause: () => storage?.save(),
    );
  }

  void dispose() {
    storage?.dispose();
    connection?.dispose();
    _lifecycle?.dispose();
    link.detach();
    compass.dispose();
    location.dispose();
    clock.dispose();
    store.dispose();
    settings.dispose();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
