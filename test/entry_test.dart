import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/data/scan_list.dart';
import 'package:tsp_tracker/services/location_service.dart';
import 'package:tsp_tracker/ui/screens/bluetooth_off_screen.dart';
import 'package:tsp_tracker/ui/screens/entry_screen.dart';
import 'package:tsp_tracker/ui/screens/find_devices_screen.dart';
import 'package:tsp_tracker/ui/screens/permissions_screen.dart';

import 'helpers.dart';

void main() {
  group('which entry screen', () {
    test('permissions first, then Bluetooth on', () {
      EntryStep step(BluetoothAdapterState b, LocationProblem l) =>
          entryStep(bluetooth: b, location: l);
      expect(
          step(BluetoothAdapterState.on, LocationProblem.none), EntryStep.scan);
      expect(step(BluetoothAdapterState.on, LocationProblem.starting),
          EntryStep.scan,
          reason: 'GPS still looking: not a permission');
      expect(step(BluetoothAdapterState.on, LocationProblem.noPermission),
          EntryStep.permissions);
      expect(step(BluetoothAdapterState.unauthorized, LocationProblem.none),
          EntryStep.permissions);
      expect(step(BluetoothAdapterState.off, LocationProblem.none),
          EntryStep.bluetoothOff);
      expect(step(BluetoothAdapterState.off, LocationProblem.noPermission),
          EntryStep.permissions);
    });
  });

  group('the scan list', () {
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
  });

  group('the screens', () {
    setUp(resetApp);

    testWidgets('scan: sections, connect, stop', (tester) async {
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
          FoundDevice(name: '', rssi: -90, device: 9),
        ],
        onConnect: (d) => connected = d,
        onScan: () {},
        onStop: () => stopped = true,
      )));

      expect(find.text('Идёт поиск, 4 с'), findsOneWidget);
      expect(find.text('Подключён'), findsOneWidget);
      expect(find.text('Связь по Bluetooth есть'), findsOneWidget);
      expect(find.text('Наши трекеры'), findsOneWidget);
      expect(find.text('Другие устройства'), findsOneWidget);
      expect(find.text('Без имени'), findsOneWidget);
      expect(find.text('Сигнал сильный'), findsOneWidget);

      await tester.tap(find.text('Подключить').first);
      expect(connected, 2);
      await tester.tap(find.text('Остановить поиск'));
      expect(stopped, isTrue);
    });

    testWidgets('scan: nothing yet, a hint', (tester) async {
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

    testWidgets('Bluetooth off: the button asks Android', (tester) async {
      var asked = false;
      await tester.pumpWidget(inApp(BluetoothOffScreen(
          title: 'Bluetooth выключен', onTurnOn: () => asked = true)));
      await tester.tap(find.text('Включить Bluetooth'));
      expect(asked, isTrue);

      await tester.pumpWidget(
          inApp(const BluetoothOffScreen(title: 'Bluetooth недоступен')));
      expect(find.text('Включить Bluetooth'), findsNothing,
          reason: 'no Bluetooth on the phone');
    });

    testWidgets('permissions: what is given and what is not', (tester) async {
      var allowed = false;
      await tester.pumpWidget(inApp(PermissionsScreen(
          bluetooth: true,
          location: false,
          onAllow: () => allowed = true,
          onOpenSettings: () {})));
      expect(find.text('Нужны разрешения'), findsOneWidget);
      expect(find.textContaining('подключиться к нему. Разрешено.'),
          findsOneWidget);
      expect(find.textContaining('для поиска Bluetooth. Не разрешено.'),
          findsOneWidget);
      await tester.tap(find.text('Разрешить'));
      expect(allowed, isTrue);
    });
  });
}
