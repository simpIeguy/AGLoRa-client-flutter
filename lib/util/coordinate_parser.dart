import 'dart:math';

import 'sk42.dart';

/// how the text was read
enum CoordinateKind {
  decimal,
  degreesMinutes,
  degreesMinutesSeconds,
  gaussKruger,
}

/// a position read from text, in WGS 84
class ParsedCoordinates {
  const ParsedCoordinates(this.latitude, this.longitude, this.kind,
      {this.zone, this.zoneGuessed = false});

  final double latitude;
  final double longitude;
  final CoordinateKind kind;

  /// the 6° zone of Gauss–Krüger text
  final int? zone;

  /// the text had no zone number in front of Y: the map's zone was taken
  final bool zoneGuessed;
}

/// a number of the text; a minus counts only at the start of a word
final _number = RegExp(r'(?:(?<![\w.,])[-−–]\s*)?\d+(?:[.,]\d+)?');

final _labelX = RegExp(r'(?:^|[^A-Za-zА-Яа-я])[XxХх]\s*[=:]?\s*([\d\s.,]+)');
final _labelY = RegExp(r'(?:^|[^A-Za-zА-Яа-я])[YyУу]\s*[=:]?\s*([\d\s.,]+)');
final _letter =
    RegExp(r'(?<![A-Za-zА-Яа-я])([NSEWnsewСЮВЗсювз])(?![A-Za-zА-Яа-я])');

/// "6 012 345,5" → 6012345.5: spaces as thousands, a comma as the point
double? _plain(String s) =>
    double.tryParse(s.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));

/// Reads what a person would send: "53.9023, 27.5618", "53°54'08"N
/// 27°33'42"E", "N 53 54.138 E 27 33.7", or the rectangular СК-42 "X 5977123
/// Y 4400123" (also "Х=… У=…", spaces in the numbers allowed). Null when it
/// is not understood. [defaultZone] is used for a Y without the zone number.
ParsedCoordinates? parseCoordinates(String text, {int? defaultZone}) {
  final s = text
      .replaceAll(' ', ' ')
      .replaceAll(RegExp('[°º˚′″’‘`´"“”\']'), ' ')
      .trim();
  if (s.isEmpty) return null;
  return _rectangular(s, defaultZone) ?? _geographic(s);
}

ParsedCoordinates? _rectangular(String s, int? defaultZone) {
  double? x, y;
  final lx = _labelX.firstMatch(s), ly = _labelY.firstMatch(s);
  if (lx != null && ly != null) {
    x = _plain(lx.group(1)!);
    y = _plain(ly.group(1)!);
  } else {
    // two big numbers, the first is X (north)
    // a space only as thousands: "5 975 056", not "53 54 08"
    final numbers = RegExp(r'\d{1,3}(?: \d{3})+(?:[.,]\d+)?|\d+(?:[.,]\d+)?')
        .allMatches(s)
        .map((m) => _plain(m.group(0)!))
        .whereType<double>()
        .toList();
    if (numbers.length != 2 || numbers.any((v) => v < 100000)) return null;
    x = numbers[0];
    y = numbers[1];
  }
  if (x == null || y == null || !x.isFinite || !y.isFinite) return null;
  if (x < 0 || x > 10000000) return null;

  var zone = (y / 1e6).floor();
  var guessed = false;
  if (zone < 1 || zone > 60) {
    // no zone number in front of Y
    if (y < 0 || y >= 1e6 || defaultZone == null) return null;
    zone = defaultZone;
    y += zone * 1e6;
    guessed = true;
  }
  final p = gaussKrugerToWgs84(x, y);
  if (!_validLatLon(p.latitude, p.longitude)) return null;
  return ParsedCoordinates(p.latitude, p.longitude, CoordinateKind.gaussKruger,
      zone: zone, zoneGuessed: guessed);
}

ParsedCoordinates? _geographic(String s) {
  final numbers = _number.allMatches(s).toList();
  if (numbers.isEmpty || numbers.length.isOdd || numbers.length > 6) {
    return null;
  }
  final per = numbers.length ~/ 2;
  final kind = switch (per) {
    1 => CoordinateKind.decimal,
    2 => CoordinateKind.degreesMinutes,
    _ => CoordinateKind.degreesMinutesSeconds,
  };

  // Hemisphere letters, before or after their numbers. Two letters: the
  // first is for the first half. One letter: for the half it stands before
  // or after; between the halves it ends the first ("53.9 N, 27.5").
  final letters = _letter.allMatches(s).toList();
  if (letters.length > 2) return null;
  String? first, second;
  if (letters.length == 2) {
    first = letters[0].group(1)!.toUpperCase();
    second = letters[1].group(1)!.toUpperCase();
  } else if (letters.length == 1) {
    final upper = letters[0].group(1)!.toUpperCase();
    if (letters[0].start >= numbers[per].start) {
      second = upper;
    } else {
      first = upper;
    }
  }
  bool isLat(String? l) => l == 'N' || l == 'S' || l == 'С' || l == 'Ю';
  bool isLon(String? l) => l == 'E' || l == 'W' || l == 'В' || l == 'З';
  bool negative(String? l) => l == 'S' || l == 'W' || l == 'Ю' || l == 'З';

  double? value(List<RegExpMatch> parts) {
    var result = 0.0;
    for (var i = 0; i < parts.length; i++) {
      final raw = parts[i].group(0)!;
      final v = double.tryParse(
          raw.replaceAll(RegExp(r'[-−–\s]'), '').replaceAll(',', '.'));
      if (v == null) return null;
      // minutes and seconds are under 60, only the last one has a fraction
      if (i > 0 && v >= 60) return null;
      if (i < parts.length - 1 && raw.contains(RegExp(r'[.,]'))) return null;
      result += v / pow(60, i);
    }
    return RegExp(r'^[-−–]').hasMatch(parts.first.group(0)!) ? -result : result;
  }

  var a = value(numbers.sublist(0, per));
  var b = value(numbers.sublist(per));
  if (a == null || b == null) return null;
  if (negative(first)) a = -a.abs();
  if (negative(second)) b = -b.abs();

  // longitude first: told by the letters, or by a first number over 90
  final swap = isLon(first) ||
      isLat(second) ||
      (first == null && second == null && a.abs() > 90);
  final lat = swap ? b : a;
  final lon = swap ? a : b;
  if (!_validLatLon(lat, lon)) return null;
  return ParsedCoordinates(lat, lon, kind);
}

bool _validLatLon(double lat, double lon) =>
    lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180;
