import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../data/scan_list.dart';
import '../../data/tracker_status.dart';
import '../../services/app_services.dart';
import '../../services/ble_data_source.dart';
import '../../util/log.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/status_dot.dart';
import 'demo_screens.dart';

/// "Подключить трекер" from the main screen's corner button
Future<void> openConnectScreen(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const FindDevicesScreen()));

/// The Bluetooth search, as in the Scan mockup. It starts by itself; the
/// connected tracker on top, then our trackers (UAV…, GROUND…), the other
/// devices folded below. A pick connects and goes back to the trackers.
class FindDevicesScreen extends StatefulWidget {
  const FindDevicesScreen({super.key});

  static const Duration scanTime = Duration(seconds: 10);

  @override
  State<FindDevicesScreen> createState() => _FindDevicesScreenState();
}

class _FindDevicesScreenState extends State<FindDevicesScreen> {
  DateTime? _scanStarted;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  // androidUsesFineLocation: Android hides scan results without location
  // permission; the app also needs it for distance and bearing to trackers
  void _scan() {
    _scanStarted = DateTime.now();
    FlutterBluePlus.startScan(
            timeout: FindDevicesScreen.scanTime, androidUsesFineLocation: true)
        .catchError((Object e) => appLog('ble: $e'));
  }

  @override
  void dispose() {
    unawaited(FlutterBluePlus.stopScan());
    super.dispose();
  }

  /// the own tracker from now on, remembered; back to the trackers
  void _connect(BluetoothDevice device) {
    final services = AppScope.of(context);
    final connection = services.connection;
    if (connection != null) {
      unawaited(connection.connectTo(device));
    } else {
      services.link.attach(BleDataSource(device));
      unawaited(device.connect().catchError((Object e) => appLog('ble: $e')));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final clock = AppScope.of(context).clock;
    return StreamBuilder<bool>(
      stream: FlutterBluePlus.isScanning,
      initialData: false,
      builder: (context, scanning) => StreamBuilder<List<ScanResult>>(
        stream: FlutterBluePlus.scanResults,
        initialData: const [],
        builder: (context, results) => StreamBuilder<List<BluetoothDevice>>(
          stream: Stream.periodic(const Duration(seconds: 2))
              .map((_) => FlutterBluePlus.connectedDevices),
          initialData: FlutterBluePlus.connectedDevices,
          builder: (context, connected) => ListenableBuilder(
            // "Идёт поиск, 4 с" counts up
            listenable: clock,
            builder: (context, _) {
              final started = _scanStarted;
              return ScanView(
                scanning: scanning.data!,
                seconds: started == null
                    ? 0
                    : clock.now.difference(started).inSeconds,
                connected: [
                  for (final d in connected.data!)
                    ConnectedDevice(
                        name: d.platformName,
                        ready: d.isConnected,
                        onOpen: () => Navigator.of(context).pop()),
                ],
                found: [
                  for (final r in results.data!)
                    if (r.advertisementData.connectable &&
                        !r.device.isConnected)
                      FoundDevice(
                          name: r.device.platformName,
                          rssi: r.rssi,
                          device: r.device),
                ],
                onConnect: _connect,
                onScan: _scan,
                onStop: FlutterBluePlus.stopScan,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// a tracker the phone is already connected to
class ConnectedDevice {
  const ConnectedDevice(
      {required this.name, required this.ready, required this.onOpen});

  final String name;

  /// false while it connects
  final bool ready;
  final VoidCallback onOpen;
}

/// The look of the scan, apart from Bluetooth so tests and the screen
/// pictures can show it.
class ScanView<T> extends StatelessWidget {
  const ScanView({
    super.key,
    required this.scanning,
    required this.seconds,
    required this.connected,
    required this.found,
    required this.onConnect,
    required this.onScan,
    required this.onStop,
  });

  final bool scanning;

  /// since the scan started
  final int seconds;
  final List<ConnectedDevice> connected;
  final List<FoundDevice<T>> found;
  final void Function(T device) onConnect;
  final VoidCallback onScan;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final split = splitFound(found);
    final muted = textTheme.bodyMedium?.copyWith(color: p.muted);

    List<Widget> group(String title, List<FoundDevice<T>> devices) => [
          if (devices.isNotEmpty) _Section(title),
          for (final d in devices)
            _FoundCard(device: d, onConnect: () => onConnect(d.device)),
        ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.gap, AppSizes.gap, AppSizes.gap, 0),
              child: Row(children: [
                IconButton(
                  tooltip: S.back,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Text(S.connectTracker,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const DemoModeButton(),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding,
                  AppSizes.gap, AppSizes.screenPadding, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: scanning ? null : 0,
                  color: p.ink,
                  backgroundColor: p.line,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, AppSizes.gap, 20, 0),
              child: Text(
                  scanning ? S.scanning(seconds) : S.scanDone(found.length),
                  style: muted),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 0,
                    AppSizes.screenPadding, AppSizes.screenPadding),
                children: [
                  if (connected.isNotEmpty) const _Section(S.sectionConnected),
                  for (final d in connected) _ConnectedCard(device: d),
                  ...group(S.sectionOurs, split.ours),
                  // headphones, watches…: folded, so ours do not get lost
                  if (split.others.isNotEmpty)
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                        childrenPadding: EdgeInsets.zero,
                        title: Text(S.otherDevices(split.others.length),
                            style:
                                textTheme.labelLarge?.copyWith(color: p.muted)),
                        children: [
                          for (final d in split.others)
                            _FoundCard(
                                device: d,
                                onConnect: () => onConnect(d.device)),
                        ],
                      ),
                    ),
                  if (connected.isEmpty && found.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSizes.screenPadding * 2),
                      child: Text(S.scanHint,
                          style: muted, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
            Container(
              decoration:
                  BoxDecoration(border: Border(top: BorderSide(color: p.line))),
              padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding,
                  AppSizes.padding, AppSizes.screenPadding, 24),
              child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.bigButton)),
                onPressed: scanning ? onStop : onScan,
                child: Text(scanning ? S.stopScan : S.startScan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, AppSizes.screenPadding, 4, 0),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: AppPalette.of(context).muted)),
      );
}

class _Card extends StatelessWidget {
  const _Card(
      {required this.leading,
      required this.title,
      required this.subtitle,
      required this.button});

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.gap),
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding, AppSizes.gap, AppSizes.gap, AppSizes.gap),
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Row(children: [
        leading,
        const SizedBox(width: AppSizes.padding),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(subtitle,
                  style: textTheme.bodyMedium?.copyWith(color: p.muted)),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.gap),
        button,
      ]),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({required this.device});

  final ConnectedDevice device;

  @override
  Widget build(BuildContext context) => _Card(
        leading: StatusDot(
            status:
                device.ready ? TrackerStatus.active : TrackerStatus.waiting),
        title: device.name.isEmpty ? S.unnamedDevice : device.name,
        subtitle: device.ready ? S.bluetoothLinkOk : S.connecting,
        button: FilledButton(
          onPressed: device.ready ? device.onOpen : null,
          child: const Text(S.open),
        ),
      );
}

class _FoundCard<T> extends StatelessWidget {
  const _FoundCard({required this.device, required this.onConnect});

  final FoundDevice<T> device;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final bars = signalBars(device.rssi);
    final level = switch (bars) {
      4 => S.signalStrong,
      1 => S.signalWeak,
      _ => S.signalMedium,
    };
    return _Card(
      leading: Semantics(
          label: S.signal(level),
          child: CustomPaint(
              size: const Size(28, 24),
              painter: _BarsPainter(bars, AppPalette.of(context)))),
      title: device.name.isEmpty ? S.unnamedDevice : device.name,
      subtitle: S.signal(level),
      button:
          OutlinedButton(onPressed: onConnect, child: const Text(S.connect)),
    );
  }
}

/// four bars, [bars] of them dark
class _BarsPainter extends CustomPainter {
  _BarsPainter(this.bars, this.p);

  final int bars;
  final AppPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 4; i++) {
      final h = 7.0 + i * 4.5;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(2 + i * 7.0, 22 - h, 4, h),
              const Radius.circular(1)),
          Paint()..color = i < bars ? p.ink : p.line);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.bars != bars || old.p != p;
}
