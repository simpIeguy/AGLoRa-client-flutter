import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'demo/demo_runner.dart';
import 'services/app_services.dart';
import 'services/app_storage.dart';
import 'ui/screens/demo_screens.dart';
import 'ui/screens/trackers_screen.dart';
import 'ui/strings.dart';
import 'ui/theme.dart';
import 'ui/widgets/broken_widget.dart';
import 'ui/widgets/crash_notice.dart';
import 'ui/widgets/first_signal_alerts.dart';
import 'util/log.dart';

Future<void> main() async {
  // every error nobody caught goes to the journal, where the user can save it
  unawaited(runZonedGuarded(_start,
      (error, stack) => AppLog.instance.error(error, stack, where: 'zone')));
}

Future<void> _start() async {
  // the compass and GPS talk to Android through the binding: without it they
  // fail silently and the app shows "no phone GPS" and no compass
  WidgetsFlutterBinding.ensureInitialized();
  await AppLog.instance.start(FileLogBackend(),
      header: '${S.appName} ${S.appVersion}, '
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  FlutterError.onError = (details) {
    AppLog.instance.error(details.exception, details.stack,
        where: details.library ?? 'flutter');
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.instance.error(error, stack, where: 'platform');
    return true;
  };
  // a widget that failed to build: a note and the journal, not a red screen
  ErrorWidget.builder = (_) => const BrokenWidget();
  // upright only: the arrow and the compass are made for a phone held up,
  // and turning the screen in a pocket or a glove only gets in the way
  await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp]);
  // the IBM Plex fonts come with their license (SIL Open Font License)
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['IBM Plex'], text);
  });
  // the trackers and settings from the last launch, before the first screen
  // and the own tracker connects again by itself (the emulator's demo
  // launch has no Bluetooth)
  final services =
      AppServices(storage: PhoneStorage(), bluetooth: !isDemoRequestedAtLaunch);
  await services.start();
  runApp(AppScope(services: services, child: TrackerApp()));
}

class TrackerApp extends StatelessWidget {
  TrackerApp({super.key});

  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, home) {
        final themes = themesFor(settings.theme);
        return MaterialApp(
          title: S.appName,
          theme: buildAppTheme(themes.light),
          darkTheme: buildAppTheme(themes.dark),
          themeMode: themes.mode,
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _messengerKey,
          builder: (context, child) => CrashNotice(
              messengerKey: _messengerKey,
              child: FirstSignalAlerts(
                  navigatorKey: _navigatorKey,
                  messengerKey: _messengerKey,
                  child: child!)),
          home: isDemoRequestedAtLaunch
              // debug builds only: --dart-define=DEMO_SCENARIO=<id> opens the demo
              ? DemoTrackersScreen(
                  scenarioId: demoScenarioFromLaunch,
                  speed: double.tryParse(demoSpeedFromLaunch) ?? 1)
              // the trackers at once; connecting is a button on it
              : const TrackersScreen(),
        );
      },
    );
  }
}
