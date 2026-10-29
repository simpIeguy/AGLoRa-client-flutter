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

  // main screen
  static const String you = 'Вы';
  static const String connectedByBluetooth = 'Подключён по Bluetooth';
  static const String noBluetoothLink = 'Нет связи по Bluetooth';
  static const String disconnectMe = 'Отключиться';
  static const String connectMe = 'Подключиться';
  static const String groupUavs = 'БЛА';
  static const String groupPeople = 'Люди';
  static const String groupOthers = 'Другие';
  static const String settings = 'Настройки';
  static String copiedValue(String value) => 'Скопировано: $value';
  static String removeWaiting(String name) => 'Убрать $name из ожидания';
  static String lostAge(String age) => '$age, последняя точка';

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
  static const String statusLost = 'Связь потеряна';
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

  // tracker screen
  static const String noPointsYet = 'Точек пока нет';
  static const String openInMaps = 'Открыть в картах';
  static const String cannotOpenMaps =
      'Не удалось открыть карты на этом телефоне';
  static const String copied = 'Скопировано';
  static const String trackerState = 'Состояние трекера';
  static const String trackerGps = 'GPS трекера';
  static const String gpsValid = 'Координаты верные';
  static const String satellites = 'Спутники';
  static const String altitude = 'Высота';
  static String metres(String v) => '$v м';
  static const String receivedByPhone = 'Принято телефоном';
  static const String gpsTime = 'Время GPS';
  static const String lastPoints = 'Последние точки';
  static String allPoints(int n) => 'Все точки: $n';
  static String copyCoordinatesAt(String time) => 'Копировать координаты $time';
  static String directionTo(String name) =>
      'Направление на $name, нажмите для полного экрана';
  static const String rename = 'Переименовать';
  static const String trackerTitle = 'Название трекера';
  static String renameHint(String raw) => 'Пусто — будет имя из прошивки, $raw';
  static const String save = 'Сохранить';
  static const String removeTracker = 'Удалить трекер из списка';
  static String removeTrackerQuestion(String name) =>
      'Удалить $name и все его точки? Если трекер на связи, он появится снова.';
  static const String delete = 'Удалить';

  // map
  static const String back = 'Назад';
  static const String mapLayers = 'Слои карты';
  static const String layerScheme = 'Схема';
  static const String layerSatellite = 'Спутник';
  static const String layerHybrid = 'Гибрид';
  static const String compassModeOff = 'Обычный режим';
  static const String compassModeOn = 'По направлению телефона';
  static const String northUp = 'Север вверх';

  // settings
  static const String sectionLook = 'Вид';
  static const String theme = 'Тема';
  static const String themeAuto = 'Авто';
  static const String themeLight = 'Светлая';
  static const String themeDark = 'Тёмная';
  static const String themeNight = 'Ночная';
  static const String themeNightHint =
      'Ночная: красные цвета на чёрном, не слепит и не сбивает ночное зрение.';

  // demo
  static const String demoMode = 'Демо-режим';
  static const String demoSpeed = 'Скорость';
  static const String demoStart = 'Запустить';
  static String demoTitle(String id, int speed) => 'Демо: $id ×$speed';
}
