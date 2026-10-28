import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aglora/aglora.dart';
import '../aglora/data_source.dart';
import '../aglora/memory.dart';
import '../screens/screen_device.dart';
import 'demo_data_source.dart';
import 'demo_scenario.dart';

/// scenario id → description; the file is assets/demo/<id>.txt
const Map<String, String> demoScenarios = {
  'normal': 'Норма: Tracker1 и Tracker2 шлют точки',
  'no_own_points': 'Как раньше в жизни: только точки Tracker2',
  'link_loss': 'Потеря связи: Tracker2 замолкает',
  'ragged': 'Рваные, склеенные и битые данные',
  'many': 'Много трекеров: 5 сразу',
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

Future<DemoDataSource> startDemo(String scenarioId, double speed,
    {AssetBundle? bundle}) async {
  final text =
      await (bundle ?? rootBundle).loadString(demoScenarioAsset(scenarioId));
  final source = DemoDataSource(parseDemoScenario(text), speed: speed);

  agloraAppMemory.reset();
  resetDataReceiver();
  attachDataSource(source);
  source.start();
  return source;
}

String demoTitle(String scenarioId, double speed) =>
    'Демо: $scenarioId ×${speed.toInt()}';

/// tracker list fed by a scenario, as if connected over BLE
class DemoDeviceScreen extends StatefulWidget {
  const DemoDeviceScreen(
      {Key? key, required this.scenarioId, required this.speed})
      : super(key: key);

  final String scenarioId;
  final double speed;

  @override
  State<DemoDeviceScreen> createState() => _DemoDeviceScreenState();
}

class _DemoDeviceScreenState extends State<DemoDeviceScreen> {
  @override
  void initState() {
    super.initState();
    startDemo(widget.scenarioId, widget.speed);
  }

  @override
  void dispose() {
    detachDataSource();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeviceScreen(demoTitle: demoTitle(widget.scenarioId, widget.speed));
  }
}

/// pick a scenario and a speed
class DemoSetupScreen extends StatefulWidget {
  const DemoSetupScreen({Key? key}) : super(key: key);

  @override
  State<DemoSetupScreen> createState() => _DemoSetupScreenState();
}

class _DemoSetupScreenState extends State<DemoSetupScreen> {
  String _scenarioId = demoScenarios.keys.first;
  double _speed = demoSpeeds.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Демо-режим')),
      body: ListView(
        children: [
          ...demoScenarios.entries.map((e) => RadioListTile<String>(
                value: e.key,
                groupValue: _scenarioId,
                title: Text(e.value),
                subtitle: Text(e.key),
                onChanged: (value) => setState(() => _scenarioId = value!),
              )),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text('Скорость'),
                SizedBox(width: 16),
                ...demoSpeeds.map((speed) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text('×${speed.toInt()}'),
                        selected: speed == _speed,
                        onSelected: (_) => setState(() => _speed = speed),
                      ),
                    )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              icon: Icon(Icons.play_arrow),
              label: Text('Запустить'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => DemoDeviceScreen(
                      scenarioId: _scenarioId, speed: _speed))),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Демо-режим" button for the start screens, debug builds only
class DemoModeButton extends StatelessWidget {
  const DemoModeButton({Key? key, this.color}) : super(key: key);

  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!isDemoAvailable) return SizedBox.shrink();
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: color),
      icon: Icon(Icons.play_circle_outline),
      label: Text('Демо-режим'),
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => DemoSetupScreen())),
    );
  }
}
