import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/tracker_status.dart';
import '../../services/app_services.dart';
import '../../services/location_service.dart';
import '../../util/log.dart';
import '../screens/find_devices_screen.dart';
import '../screens/permissions_screen.dart';
import '../strings.dart';
import '../theme.dart';
import 'status_dot.dart';

/// what keeps the app from working, shown over the list
enum LinkProblem { none, permissions, bluetoothOff, noBluetooth, locationOff }

/// Permissions first: without them neither the search nor the arrow work.
/// "Unknown" and "turning on" are not a problem, only a moment.
LinkProblem linkProblem(
    {required BluetoothAdapterState bluetooth,
    required LocationProblem location}) {
  if (bluetooth == BluetoothAdapterState.unauthorized ||
      location == LocationProblem.noPermission) {
    return LinkProblem.permissions;
  }
  return switch (bluetooth) {
    BluetoothAdapterState.off ||
    BluetoothAdapterState.turningOff =>
      LinkProblem.bluetoothOff,
    BluetoothAdapterState.unavailable => LinkProblem.noBluetooth,
    // the location is off: no distance, no arrow, and on many phones Android
    // gives no Bluetooth search results either
    _ when location == LocationProblem.serviceOff => LinkProblem.locationOff,
    _ => LinkProblem.none,
  };
}

/// The top right button of the main screen: is the own tracker connected;
/// a tap opens the search.
class ConnectButton extends StatelessWidget {
  const ConnectButton({super.key});

  @override
  Widget build(BuildContext context) {
    final connection = AppScope.of(context).connection;
    if (connection == null) {
      return IconButton(
        tooltip: S.connectTracker,
        icon: const Icon(Icons.bluetooth),
        onPressed: () => openConnectScreen(context),
      );
    }
    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        final (icon, tip) = connection.isConnected
            ? (Icons.bluetooth_connected, S.trackerConnected)
            : connection.isConnecting
                ? (Icons.bluetooth_searching, S.connectingToOwn)
                : (Icons.bluetooth, S.connectTracker);
        return IconButton(
          tooltip: tip,
          icon: Icon(icon),
          onPressed: () => openConnectScreen(context),
        );
      },
    );
  }
}

/// "Bluetooth выключен" or "Нужны разрешения" over the list, with what to
/// do; nothing when all is well
class LinkBanner extends StatelessWidget {
  const LinkBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final connection = services.connection;
    return ListenableBuilder(
      listenable: Listenable.merge(
          [services.location, if (connection != null) connection]),
      builder: (context, _) {
        final problem = linkProblem(
            bluetooth: connection?.adapter ?? BluetoothAdapterState.unknown,
            location: services.location.problem);
        return switch (problem) {
          LinkProblem.none => const SizedBox.shrink(),
          LinkProblem.permissions => _Banner(
              title: S.permissionsNeeded,
              hint: S.permissionsHint,
              action: S.details,
              onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _Permissions())),
            ),
          LinkProblem.bluetoothOff => _Banner(
              title: S.bluetoothState('off'),
              hint: S.bluetoothOffHint,
              action: S.turnOn,
              onAction: () => FlutterBluePlus.turnOn()
                  .catchError((Object e) => appLog('ble: $e')),
            ),
          LinkProblem.noBluetooth => const _Banner(
              title: S.noBluetoothOnPhone, hint: S.bluetoothOffHint),
          LinkProblem.locationOff => _Banner(
              title: S.locationOff,
              hint: S.locationOffHint,
              action: S.turnOn,
              onAction: () => Geolocator.openLocationSettings(),
            ),
        };
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(
      {required this.title, required this.hint, this.action, this.onAction});

  final String title;
  final String hint;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, AppSizes.gap, AppSizes.gap, 0),
      padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding,
          AppSizes.padding, AppSizes.gap, AppSizes.padding),
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Row(children: [
        // the amber dot: something to fix
        const StatusDot(status: TrackerStatus.fading),
        const SizedBox(width: AppSizes.padding),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              Text(hint, style: textTheme.bodyMedium?.copyWith(color: p.muted)),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: AppSizes.gap),
          FilledButton(onPressed: onAction, child: Text(action!)),
        ],
      ]),
    );
  }
}

/// "Нужны разрешения" in full, from the banner
class _Permissions extends StatelessWidget {
  const _Permissions();

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final connection = services.connection;
    return ListenableBuilder(
      listenable: Listenable.merge(
          [services.location, if (connection != null) connection]),
      builder: (context, _) {
        final bluetooth =
            connection?.adapter != BluetoothAdapterState.unauthorized;
        final location =
            services.location.problem != LocationProblem.noPermission;
        if (bluetooth && location) {
          // given: back to the trackers by itself
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
        }
        return PermissionsScreen(
          bluetooth: bluetooth,
          location: location,
          onAllow: () {
            services.location.retry();
            // the search is what makes Android ask for Bluetooth
            FlutterBluePlus.startScan(
                    timeout: const Duration(seconds: 1),
                    androidUsesFineLocation: true)
                .catchError((Object e) => appLog('ble: $e'));
          },
          onOpenSettings: Geolocator.openAppSettings,
        );
      },
    );
  }
}
