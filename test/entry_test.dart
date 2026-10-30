import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/scan_list.dart';
import 'package:tsp_tracker/services/app_settings.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/find_devices_screen.dart';
import 'package:tsp_tracker/ui/screens/permissions_screen.dart';
import 'package:tsp_tracker/ui/screens/trackers_screen.dart';
import 'package:tsp_tracker/ui/widgets/link_banner.dart';

import 'helpers.dart';

void main() {
  group('what keeps Bluetooth from working', () {
    test('permissions first; unknown or turning on is not a problem', () {
      LinkProblem problem(BluetoothAdapterState b, LocationProblem l) =>
          linkProblem(bluetooth: b, location: l);
      expect(problem(BluetoothAdapterState.on, LocationProblem.none),
          LinkProblem.none);
      expect(problem(BluetoothAdapterState.unknown, LocationProblem.starting),
          LinkProblem.none,
          reason: 'the first moment after the start');
      expect(problem(BluetoothAdapterState.turningOn, LocationProblem.none),
          LinkProblem.none);
      expect(problem(BluetoothAdapterState.on, LocationProblem.noPermission),
          LinkProblem.permissions);
      expect(problem(BluetoothAdapterState.unauthorized, LocationProblem.none),
          LinkProblem.permissions);
      expect(problem(BluetoothAdapterState.off, LocationProblem.none),
          LinkProblem.bluetoothOff);
      expect(problem(BluetoothAdapterState.off, LocationProblem.noPermission),
          LinkProblem.permissions);
      expect(problem(BluetoothAdapterState.unavailable, LocationProblem.none),
          LinkProblem.noBluetooth);
    });
  });

  group('the search list', () {
    test('our trackers apart, the strongest first', () {
      final split = splitFound([
        const FoundDevice(name: 'Наушники', rssi: -50, device: 1),
        const FoundDevice(name: 'UAV2', rssi: -85, device: 2),
        const FoundDevice(name: 'GROUND1', rssi: -55, device: 3),
        const FoundDevice(name: '', rssi: -90, device: 4),
      ]);
      expect(split.ours.map((d) => d.device), [3, 2]);
      expect(split.others.map((d) => d.device), [1, 4]);
    });

    test('signal bars', () {
      expect([-50, -65, -75, -95].map(signalBars), [4, 3, 2, 1]);
    });

    test('the own tracker is remembered between launches', () {
      final before = AppSettings()
        ..lastTracker = (id: 'AA:BB:CC:DD:EE:FF', name: 'GROUND1');
      final after = AppSettings()..loadState(before.saveState());
      expect(after.lastTracker, (id: 'AA:BB:CC:DD:EE:FF', name: 'GROUND1'));
      before.lastTracker = null;
      expect(
          (AppSettings()..loadState(before.saveState())).lastTracker, isNull);
    });
  });

  group('the screens', () {
    setUp(resetApp);

    testWidgets('the app opens on the trackers, connecting is a button',
        (tester) async {
      await tester.pumpWidget(inApp(const TrackersScreen()));
      expect(find.text('Не подключён'), findsOneWidget);
      expect(find.byTooltip('Подключить трекер'), findsOneWidget);
      expect(find.text('Подключиться'), findsOneWidget);
    });

    testWidgets('no location permission: a banner, details on a tap',
        (tester) async {
      resetApp(location: LocationService(open: (setProblem) async {
        setProblem(LocationProblem.noPermission);
        return null;
      }));
      await tester.pumpWidget(inApp(const TrackersScreen()));
      await tester.pump();
      expect(find.text('Нужны разрешения'), findsOneWidget);
      await tester.tap(find.text('Подробнее'));
      await tester.pumpAndSettle();
      expect(find.byType(PermissionsScreen), findsOneWidget);
    });

    testWidgets('search: ours on top, the others folded', (tester) async {
      int? connected;
      var stopped = false;
      await tester.pumpWidget(inApp(ScanView<int>(
        scanning: true,
        seconds: 4,
        connected: [
          ConnectedDevice(name: 'GROUND1', ready: true, onOpen: () {}),
        ],
        found: const [
          FoundDevice(name: 'UAV2', rssi: -55, device: 2),
          FoundDevice(name: 'Наушники', rssi: -50, device: 8),
          FoundDevice(name: '', rssi: -90, device: 9),
        ],
        onConnect: (d) => connected = d,
        onScan: () {},
        onStop: () => stopped = true,
      )));

      expect(find.text('Подключить трекер'), findsOneWidget);
      expect(find.text('Идёт поиск, 4 с'), findsOneWidget);
      expect(find.text('Подключён'), findsOneWidget);
      expect(find.text('Наши трекеры'), findsOneWidget);
      expect(find.text('Другие устройства: 2'), findsOneWidget);
      expect(find.text('Наушники'), findsNothing, reason: 'folded');

      await tester.tap(find.text('Подключить').first);
      expect(connected, 2);

      await tester.tap(find.text('Другие устройства: 2'));
      // the search bar never settles: a fixed wait for the unfolding
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Наушники'), findsOneWidget);
      expect(find.text('Без имени'), findsOneWidget);

      await tester.tap(find.text('Остановить поиск'));
      expect(stopped, isTrue);
    });

    testWidgets('search: nothing yet, a hint', (tester) async {
      await tester.pumpWidget(inApp(ScanView<int>(
        scanning: false,
        seconds: 10,
        connected: const [],
        found: const [],
        onConnect: (_) {},
        onScan: () {},
        onStop: () {},
      )));
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(find.textContaining('Включите трекер'), findsOneWidget);
      expect(find.text('Искать снова'), findsOneWidget);
    });

    testWidgets('permissions: what is given and what is not', (tester) async {
      var allowed = false;
      await tester.pumpWidget(inApp(PermissionsScreen(
          bluetooth: true,
          location: false,
          onAllow: () => allowed = true,
          onOpenSettings: () {})));
      expect(find.textContaining('подключиться к нему. Разрешено.'),
          findsOneWidget);
      expect(find.textContaining('для поиска Bluetooth. Не разрешено.'),
          findsOneWidget);
      await tester.tap(find.text('Разрешить'));
      expect(allowed, isTrue);
    });
  });
}
