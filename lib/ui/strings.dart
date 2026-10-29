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
  static const String open = 'Открыть';
  static const String connecting = 'Подключение…';
  static const String unnamedDevice = 'Без имени';
  static const String stopScan = 'Остановить поиск';
  static const String startScan = 'Искать снова';
  static String scanning(int seconds) => 'Идёт поиск, $seconds с';
  static String scanDone(int found) =>
      found == 0 ? 'Ничего не найдено' : 'Найдено: $found';
  static const String scanHint =
      'Включите трекер и поднесите телефон ближе. Список обновится сам.';
  static const String sectionConnected = 'Подключён';
  static const String sectionOurs = 'Наши трекеры';
  static const String sectionOtherDevices = 'Другие устройства';
  static const String bluetoothLinkOk = 'Связь по Bluetooth есть';
  static String signal(String level) => 'Сигнал $level';
  static const String signalStrong = 'сильный';
  static const String signalMedium = 'средний';
  static const String signalWeak = 'слабый';

  // Bluetooth off, permissions
  static const String bluetoothOffHint =
      'Телефон связывается с трекером по Bluetooth. Включите его, и список трекеров появится сам.';
  static const String turnOnBluetooth = 'Включить Bluetooth';
  static const String permissionsNeeded = 'Нужны разрешения';
  static const String permissionsHint =
      'Без них приложение не найдёт трекер и не покажет, куда идти. Ничего не отправляется в интернет.';
  static const String permBluetooth = 'Bluetooth';
  static const String permBluetoothWhy =
      'Чтобы найти трекер и подключиться к нему.';
  static const String permLocation = 'Местоположение';
  static const String permLocationWhy =
      'Чтобы показать расстояние и направление до трекера. Android требует его и для поиска Bluetooth.';
  static const String allowed = 'Разрешено.';
  static const String notAllowed = 'Не разрешено.';
  static const String allow = 'Разрешить';
  static const String openAppSettings = 'Открыть настройки приложения';

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
  static const String fullScreenHint = 'Стрелка, нажмите для полного экрана';

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
  static const String trackerName = 'Имя трекера';
  static const String waitNameHint =
      'Например uav1, UAV 1, ground2, или выберите ниже';
  static const String notRecognized =
      'Не похоже на имя трекера. Нужно UAV или GROUND и номер, например UAV1';
  static const String alreadyInList = 'Этот трекер уже в списке';
  static String chosen(List<String> keys) => 'Выбрано: ${keys.join(', ')}';
  static const String aliasOptional = 'Название (необязательно)';
  static const String aliasExample = 'Красный самолёт';
  static const String aliasOnlyForOne =
      'Название можно дать, когда выбран один трекер';
  static const String notifyWhenOnAir = 'Уведомить, когда появится';
  static String waitFor(String name) => 'Ждать $name';

  /// "Ждать 3 трекера", "Ждать 5 трекеров", "Ждать 21 трекер"
  static String waitForCount(int n) {
    final tens = n % 100, ones = n % 10;
    final word = tens >= 11 && tens <= 14
        ? 'трекеров'
        : ones == 1
            ? 'трекер'
            : ones >= 2 && ones <= 4
                ? 'трекера'
                : 'трекеров';
    return 'Ждать $n $word';
  }

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
  static const String exitFullScreen = 'Двойной тап — выйти';
  static const String toLastKnownPoint =
      'Стрелка ведёт к последней известной точке';
  static const String noPhoneGps = 'Нет сигнала GPS';
  static const String noPhoneGpsHint =
      'Выйдите на открытое место. Стрелка и расстояние появятся, когда телефон найдёт спутники.';
  static const String noCompassHint =
      'Направление показано так, будто верх телефона смотрит на север';
  static const String roughDirection = 'направление приблизительное';
  // a no-break space: "±6 м" never splits over two lines
  static String gpsAccuracyLine(int metres) => 'точность GPS ±$metres м';
  static const String gpsAccuracyUnknown = 'точность GPS: нет данных';
  static const String lastPoint = 'Последняя точка';
  static String lastPointOf(String name) => 'Последняя точка $name';
  static String arrowTo(String name) => 'Стрелка направления на $name';

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
  static String allPoints(int n) => 'Точки: $n';
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
  static const String whereAmI = 'Где я';
  static const String tracks = 'След';
  static const String tracksTitle = 'Чьи следы показывать';
  static const String tracksHint = 'Последние 50 точек каждого трекера';

  // settings
  static const String sectionLook = 'Вид';
  static const String theme = 'Тема';
  static const String themeAuto = 'Авто';
  static const String themeLight = 'Светлая';
  static const String themeDark = 'Тёмная';
  static const String themeNight = 'Ночная';
  static const String themeNightHint =
      'Ночная: красные цвета на чёрном, не слепит и не сбивает ночное зрение.';
  static const String sectionCoordinates = 'Координаты';
  static const String coordinatesDecimal = 'Десятичные градусы (DD), WGS 84';
  static const String coordinatesDms = 'Градусы, минуты, секунды (DMS), WGS 84';
  static const String sectionNotifications = 'Уведомления';
  static const String everyNewUav = 'О каждом новом БЛА';
  static const String everyNewUavHint = 'Звук и вибрация, один раз';
  static const String sectionLink = 'Связь с трекером';
  static const String fadingAfter = 'Связь пропадает после';
  static const String lostAfter = 'Связь потеряна после';
  static const String thresholdsHint =
      'Время считается от последней принятой точки. Подберите под то, как часто трекеры шлют координаты.';
  static const String sectionScreen = 'Экран';
  static const String keepScreenOn = 'Не гасить в полном экране';
  static const String keepScreenOnHint = 'Расходует батарею';
  static const String sectionData = 'Данные';
  static const String clearMemory = 'Очистить память приложения';
  static const String clearMemoryQuestion = 'Удалить все трекеры и точки?';
  static const String clearMemoryHint =
      'Трекеры, которые на связи, появятся снова.';
  static const String memoryCleared = 'Память очищена';

  /// keep in step with "version:" in pubspec.yaml (a test checks it)
  static const String appVersion = '1.0.0';
  static const String about = '$appName $appVersion';

  // demo
  static const String demoMode = 'Демо-режим';
  static const String demoSpeed = 'Скорость';
  static const String demoStart = 'Запустить';
  static String demoTitle(String id, int speed) => 'Демо: $id ×$speed';
}
