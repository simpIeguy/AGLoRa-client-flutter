/// Every text the user sees. The app is in Russian only; to translate it
/// later, this is the file to replace.
abstract final class S {
  // the name on the phone's screen is in android/.../values/strings.xml
  static const String appName = 'Поиск БЛА';

  // Bluetooth
  static const String findTrackers = 'Поиск трекеров';
  static String bluetoothState(String? state) => switch (state) {
        'off' => 'Bluetooth выключен',
        'on' => 'Bluetooth включён',
        'unauthorized' => 'Нет разрешения на Bluetooth',
        'unavailable' => 'Bluetooth недоступен',
        'turningOn' => 'Bluetooth включается…',
        'turningOff' => 'Bluetooth выключается…',
        _ => 'Bluetooth: нет данных',
      };
  static const String connect = 'Подключить';
  static const String disconnect = 'Отключить';
  static const String open = 'Открыть';
  static const String connecting = 'Подключение…';
  static const String disconnecting = 'Отключение…';
  static const String deviceConnected = 'подключён';
  static const String unnamedDevice = 'без имени';
  static const String stopScan = 'Остановить поиск';
  static const String startScan = 'Искать';

  // tracker list
  static const String noTrackersYet = 'Трекеров пока нет';
  static const String toTracker = 'на трекер';
  static const String distance = 'расстояние';
  static const String tracker = 'трекер';
  static const String coordinates = 'координаты';
  static const String map = 'Карта';
  static const String sensors = 'Датчики';
  static const String useCompass = 'Компас телефона';

  // log
  static String logTitle(String name) => 'Лог: $name';
  static const String noPointsYet = 'Точек пока нет';
  static const String openInMaps = 'Открыть в картах';
  static const String cannotOpenMaps =
      'Не удалось открыть карты на этом телефоне';
  static const String copied = 'Скопировано';
  static String received(String clock, String age) => 'Принято $clock, $age';
  static String gpsTime(String clock) => 'GPS-время $clock';
  static String altitude(String v) => 'высота $v м';
  static String speed(String v) => 'скорость $v';
  static String satellites(String v) => 'спутники $v';
  static const String gpsOk = 'GPS ок';
  static const String gpsNo = 'GPS нет';
  static String battery(String v) => 'батарея $v%';

  // map
  static const String back = 'Назад';
  static const String mapLayers = 'Слои карты';
  static const String layerScheme = 'Схема';
  static const String layerSatellite = 'Спутник';
  static const String layerHybrid = 'Гибрид';
  static const String compassModeOff = 'Обычный режим';
  static const String compassModeOn = 'По направлению телефона';
  static const String northUp = 'Север вверх';

  // demo
  static const String demoMode = 'Демо-режим';
  static const String demoSpeed = 'Скорость';
  static const String demoStart = 'Запустить';
  static String demoTitle(String id, int speed) => 'Демо: $id ×$speed';
}
