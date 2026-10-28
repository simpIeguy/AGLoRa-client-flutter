/// The tracker's BLE protocol: text messages `AGLoRa-<type>&key=value&…|`.
/// The format is set by the firmware (sendToPhone.cpp, aglora.cpp), the app
/// must follow it.
library;

const String messagePrefix = 'AGLoRa-';
const String messageTerminator = '|';

/// app → tracker requests (AGLORA::getRequest in the firmware)
const String requestAll = 'all';
const String requestCrc = 'crc';
const String requestClear = 'clear';
String requestPoint(int index) => 'id$index';
