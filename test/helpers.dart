import 'package:aglora_client/aglora/aglora.dart';
import 'package:aglora_client/aglora/data_source.dart';
import 'package:aglora_client/aglora/memory.dart';
import 'package:aglora_client/demo/demo_scenario.dart';

void resetApp() {
  detachDataSource();
  agloraAppMemory.reset();
  resetDataReceiver();
}

/// a "point" message in the firmware's format
String pointMessage(String name, double lat, double lon, DateTime time,
    {int? index, double alt = 120.5, int battery = 87}) {
  return 'AGLoRa-point&ver=2.3&dev_batt=100&name=$name'
      '&lat=${lat.toStringAsFixed(6)}&lon=${lon.toStringAsFixed(6)}'
      '&timestamp=${formatAgloraTimestamp(time)}'
      '&gpsValid=1&sat=9&alt=${alt.toStringAsFixed(1)}&battery=$battery'
      '&dev_bat=100${index == null ? '' : '&index=$index&crc=ok'}|';
}

String memoryMessage(String deviceName) =>
    'AGLoRa-memory&ver=2.3&crc=ok&dev_name=$deviceName&dev_bat=100'
    '&memsize=100&index=0&overwrite=0|';

/// like the firmware with USE_BLE_MTU: pieces of [mtu] characters
void feed(String text, {int mtu = 20}) {
  for (int i = 0; i < text.length; i += mtu) {
    final end = i + mtu < text.length ? i + mtu : text.length;
    newDataReceiver(text.substring(i, end).codeUnits);
  }
}
