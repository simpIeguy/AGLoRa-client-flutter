import 'package:flutter/material.dart';
import 'package:tsp_tracker/demo/demo_scenario.dart';
import 'package:tsp_tracker/services/app_services.dart';
import 'package:tsp_tracker/services/compass_service.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/services/map_link.dart';
import 'package:tsp_tracker/ui/theme.dart';

/// the app under test; made fresh by [resetApp] before every test
late AppServices app;

/// the screen kept on (true) or let go (false), in order
final List<bool> screenKept = [];

/// no real sensors, no timers: the tests tick the clock themselves
void resetApp({
  Stream<PhonePosition>? positions,
  Stream<CompassReading>? compass,
  UrlOpener? openUrl,
}) {
  screenKept.clear();
  app = AppServices(
    location: LocationService(positions: positions ?? const Stream.empty()),
    compass: CompassService(readings: compass ?? const Stream.empty()),
    openUrl: openUrl ?? (_) async => true,
    keepScreenOn: (on) async => screenKept.add(on),
  );
  app.compass.start();
  app.location.start();
}

/// a screen inside the app's scope and theme; the theme follows the
/// settings, as in the app
Widget inApp(
  Widget home, {
  GlobalKey<NavigatorState>? navigatorKey,
  GlobalKey<ScaffoldMessengerState>? messengerKey,
  TransitionBuilder? builder,
}) =>
    AppScope(
        services: app,
        child: ListenableBuilder(
          listenable: app.settings,
          builder: (context, _) {
            final themes = themesFor(app.settings.theme);
            return MaterialApp(
              theme: buildAppTheme(themes.light),
              darkTheme: buildAppTheme(themes.dark),
              themeMode: themes.mode,
              navigatorKey: navigatorKey,
              scaffoldMessengerKey: messengerKey,
              builder: builder,
              home: home,
            );
          },
        ));

/// a "point" message exactly as the firmware sends it (aglora.cpp)
String pointMessage(String name, double lat, double lon, DateTime time,
    {int? index, double alt = 120.5, int battery = 87}) {
  return 'AGLoRa-point&ver=2.3&dev_batt=100&name=$name'
      '&lat=${lat.toStringAsFixed(6)}&lon=${lon.toStringAsFixed(6)}'
      '&timestamp=${formatAgloraTimestamp(time)}'
      '&gpsValid=1&sat=9&alt=${alt.toStringAsFixed(1)}&battery=$battery'
      '&dev_bat=100${index == null ? '' : '&index=$index&crc=ok'}\r\n';
}

String memoryMessage(String deviceName) =>
    'AGLoRa-memory&ver=2.3&crc=ok&dev_name=$deviceName&dev_bat=100'
    '&memsize=100&index=0&overwrite=0\r\n';

/// like the firmware with USE_BLE_MTU: pieces of [mtu] characters
void feed(String text, {int mtu = 20}) {
  for (int i = 0; i < text.length; i += mtu) {
    final end = i + mtu < text.length ? i + mtu : text.length;
    app.link.receive(text.substring(i, end).codeUnits);
  }
}

/// broadcast streams deliver in microtasks: let them run
Future<void> flush() => Future<void>.delayed(Duration.zero);
