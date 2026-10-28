const String myIDPrefix = 'myId=';
const String devNamePrefix = 'dev_name=';

/// name of the connected tracker, sent in the "memory" message
String? deviceNameParsing(List<String> fields) {
  for (final field in fields) {
    if (field.trim().startsWith(devNamePrefix)) {
      return field.trim().substring(devNamePrefix.length);
    }
  }
  return null;
}

String? newInfoParsing(List<String> fields) {
  String? result;

  fields.forEach((field) {
    if (field.trim().startsWith(myIDPrefix)) {
      print(field);
      result = field.substring(myIDPrefix.length, field.length);
    }
  });

  return result;
}
