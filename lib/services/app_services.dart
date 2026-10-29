import 'package:flutter/widgets.dart';

import '../data/tracker_store.dart';
import 'app_settings.dart';
import 'clock.dart';
import 'compass_service.dart';
import 'location_service.dart';
import 'map_link.dart';
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
  })  : settings = settings ?? AppSettings(),
        store = store ?? TrackerStore(),
        compass = compass ?? CompassService(),
        location = location ?? LocationService(),
        clock = clock ?? Clock() {
    link = TrackerLink(this.store);
  }

  final AppSettings settings;
  final TrackerStore store;
  final CompassService compass;
  final LocationService location;
  final Clock clock;
  late final TrackerLink link;

  /// opens links outside the app (map apps)
  final UrlOpener openUrl;

  AppLifecycleListener? _lifecycle;

  /// sensors and the timer; Bluetooth starts from the screens
  void start() {
    compass.start();
    location.start();
    clock.start();
    // back from a permission dialog or the phone's settings: the location
    // may be allowed or switched on now
    _lifecycle = AppLifecycleListener(onResume: location.retry);
  }

  void dispose() {
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
