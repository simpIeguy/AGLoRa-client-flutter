/// One quick pick of the "Ждать трекер" screen. [taken]: already in the
/// list, shown but not chosen.
typedef QuickName = ({String key, bool taken});

/// The names to offer: UAV1, UAV2… up to the first [freeUavs] free ones,
/// then GROUND1… up to the first [freePeople] free ones. The taken ones
/// before them stay, so the numbers go in a row.
List<QuickName> quickWaitNames(bool Function(String key) isKnown,
    {int freeUavs = 2, int freePeople = 1}) {
  List<QuickName> run(String prefix, int free) {
    final names = <QuickName>[];
    // a limit, so a list full of trackers does not grow the screen
    for (int n = 1; free > 0 && n <= 20; n++) {
      final key = '$prefix$n';
      final taken = isKnown(key);
      names.add((key: key, taken: taken));
      if (!taken) free--;
    }
    return names;
  }

  return [...run('UAV', freeUavs), ...run('GROUND', freePeople)];
}
