import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'demo/demo_runner.dart';
import 'services/app_services.dart';
import 'ui/screens/demo_screens.dart';
import 'ui/screens/entry_screen.dart';
import 'ui/strings.dart';
import 'ui/theme.dart';
import 'ui/widgets/first_signal_alerts.dart';

void main() {
  // the compass and GPS talk to Android through the binding: without it they
  // fail silently and the app shows "no phone GPS" and no compass
  WidgetsFlutterBinding.ensureInitialized();
  // the IBM Plex fonts come with their license (SIL Open Font License)
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['IBM Plex'], text);
  });
  final services = AppServices()..start();
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
          builder: (context, child) => FirstSignalAlerts(
              navigatorKey: _navigatorKey,
              messengerKey: _messengerKey,
              child: child!),
          home: isDemoRequestedAtLaunch
              // debug builds only: --dart-define=DEMO_SCENARIO=<id> opens the demo
              ? DemoTrackersScreen(
                  scenarioId: demoScenarioFromLaunch,
                  speed: double.tryParse(demoSpeedFromLaunch) ?? 1)
              : const EntryScreen(),
        );
      },
    );
  }
}
