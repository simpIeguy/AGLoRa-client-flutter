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
  static const String copyCoordinates = 'Копировать координаты';
  static const String fullScreenHint =
      'Двойной тап или долгое нажатие на стрелку — полный экран';

  // names: UAV1 → "БЛА 1", GROUND2 → "Человек 2"
  static const String uav = 'БЛА';
  static const String person = 'Человек';

  // statuses: color is never the only sign
  static const String statusConnected = 'Подключён к телефону';
  static const String statusActive = 'Связь есть';
  static const String statusFading = 'Связь пропадает';
  static const String statusLost = 'Связь потеряна, последняя точка';
  static const String statusWaiting = 'Ждём первый сигнал';

  // on air, but the tracker's GPS has no fix
  static const String searchingSatellites = 'Трекер ищет спутники';
  static const String noFixLastGoodPoint =
      'Нет спутников, показана последняя верная точка';

  // waiting for a tracker
  static const String waitTracker = 'Ждать трекер';
  static const String waitNameHint = 'Имя трекера: uav1, UAV 1, ground2…';
  static String recognized(String key, String name) =>
      'Распознано: $key → $name';
  static const String notRecognized =
      'Не похоже на имя трекера. Нужно UAV или GROUND и номер, например UAV1';
  static const String alreadyInList = 'Этот трекер уже в списке';
  static const String aliasOptional = 'Своё название (необязательно)';
  static const String add = 'Добавить';
  static const String cancel = 'Отмена';
  static const String remove = 'Убрать';

  // who is shown
  static const String whoToShow = 'Кого показывать';
  static const String uavsAlwaysShown = 'БЛА видны всегда';
  static const String connectedAlwaysShown = 'свой трекер виден всегда';
  static String hiddenCount(int n) => 'Скрыто: $n';
  static String archive(int n) => 'Архив, нет данных 7 дней: $n';
  static const String alertNewUavs = 'Сообщать о каждом новом БЛА';
  static const String close = 'Закрыть';

  // the first signal
  static String cameOnline(String name) => '$name вышел на связь';
  static const String copy = 'Копировать';

  // arrow problems
  static const String noPhonePosition = 'Нет GPS телефона';
  static const String noCompass = 'Компас не работает';
  static const String compassUnreliable =
      'Компас неточный: помашите телефоном восьмёркой';

  // lamps
  static String gpsAccuracy(int metres) => 'GPS ±$metres м';
  static const String gpsNoAccuracy = 'GPS есть';
  static const String gpsNone = 'GPS нет позиции';
  static const String compassGood = 'Компас точный';
  static const String compassFair = 'Компас средний';
  static const String compassBad = 'Компас неточный';
  static const String compassOff = 'Компас выключен';
  static const String compassNone = 'Компаса нет';
  static const String figureEight = 'Помашите телефоном восьмёркой';

  // full screen
  static const String azimuth = 'азимут';
  static const String exitFullScreen = 'Двойной тап — выход';

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
