import 'dart:async';

import 'package:flutter/material.dart';

import '../../demo/demo_runner.dart';
import '../../services/app_services.dart';
import '../strings.dart';
import '../theme.dart';
import 'trackers_screen.dart';

/// tracker list fed by a scenario, as if connected over BLE
class DemoTrackersScreen extends StatefulWidget {
  const DemoTrackersScreen(
      {super.key, required this.scenarioId, required this.speed});

  final String scenarioId;
  final double speed;

  @override
  State<DemoTrackersScreen> createState() => _DemoTrackersScreenState();
}

class _DemoTrackersScreenState extends State<DemoTrackersScreen> {
  late final AppServices _services = AppScope.of(context);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_start());
  }

  Future<void> _start() async {
    // the user's trackers are written down first; the made-up ones are
    // never kept
    await _services.storage?.pause();
    if (!mounted) return;
    await startDemo(_services, widget.scenarioId, widget.speed,
        isWanted: () => mounted);
  }

  @override
  void dispose() {
    final services = _services;
    // after the tree settles: both tell the listeners about the change
    scheduleMicrotask(() {
      services.link.detach();
      // made-up trackers must not mix with real ones
      services.store.reset();
      // and the user's own come back
      services.storage?.resume();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TrackersScreen(
        demoTitle: S.demoTitle(widget.scenarioId, widget.speed.toInt()));
  }
}

/// pick a scenario and a speed
class DemoSetupScreen extends StatefulWidget {
  const DemoSetupScreen({super.key});

  @override
  State<DemoSetupScreen> createState() => _DemoSetupScreenState();
}

class _DemoSetupScreenState extends State<DemoSetupScreen> {
  String _scenarioId = demoScenarios.keys.first;
  double _speed = demoSpeeds.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.demoMode)),
      body: ListView(
        children: [
          RadioGroup<String>(
            groupValue: _scenarioId,
            onChanged: (value) => setState(() => _scenarioId = value!),
            child: Column(children: [
              for (final e in demoScenarios.entries)
                RadioListTile<String>(
                  value: e.key,
                  title: Text(e.value),
                  subtitle: Text(e.key),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Row(
              children: [
                const Text(S.demoSpeed),
                const SizedBox(width: AppSizes.padding),
                for (final speed in demoSpeeds)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSizes.gap),
                    child: ChoiceChip(
                      label: Text('×${speed.toInt()}'),
                      selected: speed == _speed,
                      onSelected: (_) => setState(() => _speed = speed),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text(S.demoStart),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DemoTrackersScreen(
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
  const DemoModeButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!isDemoAvailable) return const SizedBox.shrink();
    return TextButton.icon(
      style: TextButton.styleFrom(
          foregroundColor:
              color ?? Theme.of(context).appBarTheme.foregroundColor),
      icon: const Icon(Icons.play_circle_outline),
      label: const Text(S.demoMode),
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const DemoSetupScreen())),
    );
  }
}
