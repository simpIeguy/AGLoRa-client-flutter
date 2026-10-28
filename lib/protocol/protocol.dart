/// The tracker's BLE protocol: text messages `AGLoRa-<type>&key=value&…`
/// ending with "\r\n". The format is set by the firmware (sendToPhone.cpp,
/// aglora.cpp, bleProtocolDivider), the app must follow it.
library;

const String messagePrefix = 'AGLoRa-';

/// the end of a message, as the firmware sends it
const String messageTerminator = '\r\n';

/// an older end of a message; the app still accepts it
const String legacyTerminator = '|';

/// app → tracker requests (AGLORA::getRequest in the firmware)
const String requestAll = 'all';
const String requestCrc = 'crc';
const String requestClear = 'clear';
String requestPoint(int index) => 'id$index';
