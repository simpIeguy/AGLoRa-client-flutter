import 'package:flutter/material.dart';

import '../../data/tracker_status.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/status_dot.dart';
import 'demo_screens.dart';

/// "Нужны разрешения", as in the NoPerm mockup: what each one is for and
/// whether it is given. The notifications row comes with the notifications
/// (plan step 8).
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({
    super.key,
    required this.bluetooth,
    required this.location,
    required this.onAllow,
    required this.onOpenSettings,
  });

  final bool bluetooth;
  final bool location;

  /// asks Android again
  final VoidCallback onAllow;

  /// after "Больше не спрашивать" only the app's settings can give them
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    const big = Size.fromHeight(AppSizes.bigButton);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(S.appName,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const DemoModeButton(),
              ]),
              Expanded(
                child: ListView(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 32, 4, 0),
                    child: Text(S.permissionsNeeded,
                        style: textTheme.headlineMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, AppSizes.gap, 4, 24),
                    child: Text(S.permissionsHint,
                        style: textTheme.bodyMedium?.copyWith(color: p.muted)),
                  ),
                  _Permission(
                      title: S.permBluetooth,
                      why: S.permBluetoothWhy,
                      given: bluetooth),
                  _Permission(
                      title: S.permLocation,
                      why: S.permLocationWhy,
                      given: location),
                ]),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: big),
                onPressed: onAllow,
                child: const Text(S.allow),
              ),
              const SizedBox(height: AppSizes.gap),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: big,
                    textStyle: const TextStyle(
                        fontFamily: AppText.sans,
                        fontSize: AppText.main,
                        fontWeight: FontWeight.w600)),
                onPressed: onOpenSettings,
                child: const Text(S.openAppSettings),
              ),
              const SizedBox(height: AppSizes.gap),
            ],
          ),
        ),
      ),
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission(
      {required this.title, required this.why, required this.given});

  final String title;
  final String why;
  final bool given;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.gap),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          // filled: given; an empty ring: not yet
          child: StatusDot(
              status: given ? TrackerStatus.active : TrackerStatus.waiting),
        ),
        const SizedBox(width: AppSizes.padding),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              Text('$why ${given ? S.allowed : S.notAllowed}',
                  style: textTheme.bodyMedium?.copyWith(color: p.muted)),
            ],
          ),
        ),
      ]),
    );
  }
}
