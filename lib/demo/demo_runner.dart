import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/app_services.dart';
import 'demo_data_source.dart';
import 'demo_scenario.dart';

/// scenario id → description; the file is assets/demo/<id>.txt
const Map<String, String> demoScenarios = {
  'normal': 'Норма: Tracker1 и Tracker2 шлют точки',
  'no_own_points': 'Как раньше в жизни: только точки Tracker2',
  'link_loss': 'Потеря связи: Tracker2 замолкает',
  'ragged': 'Рваные, склеенные и битые данные',
  'many': 'Много трекеров: 5 сразу',
  'search': 'Поиск БЛА: UAV1 выходит на связь, UAV2 пропадает',
};

const List<double> demoSpeeds = [1, 10];

/// set at launch: flutter run --dart-define=DEMO_SCENARIO=normal
const String demoScenarioFromLaunch = String.fromEnvironment('DEMO_SCENARIO');
const String demoSpeedFromLaunch =
    String.fromEnvironment('DEMO_SPEED', defaultValue: '1');

/// the demo exists only in debug builds
bool get isDemoAvailable => kDebugMode;

bool get isDemoRequestedAtLaunch =>
    isDemoAvailable && demoScenarios.containsKey(demoScenarioFromLaunch);

String demoScenarioAsset(String id) => 'assets/demo/$id.txt';

/// forgets the trackers and plays the scenario as if it came over BLE;
/// null when [isWanted] says the demo screen closed while the file loaded
Future<DemoDataSource?> startDemo(
    AppServices services, String scenarioId, double speed,
    {AssetBundle? bundle, bool Function()? isWanted}) async {
  final text =
      await (bundle ?? rootBundle).loadString(demoScenarioAsset(scenarioId));
  if (isWanted != null && !isWanted()) return null;
  final source = DemoDataSource(parseDemoScenario(text), speed: speed);

  services.store.reset();
  services.link.attach(source);
  source.start();
  return source;
}
