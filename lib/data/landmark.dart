/// A point the user put on the map by its coordinates, for orientation: a
/// meeting place, a field edge told over the radio. Not a tracker.
class Landmark {
  const Landmark({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.visible = true,
  });

  /// unique among the landmarks, kept between launches
  final int id;
  final String name;
  final double latitude;
  final double longitude;

  /// drawn on the map; a hidden one stays in the list
  final bool visible;

  Landmark withVisible(bool visible) => Landmark(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      visible: visible);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'visible': visible,
      };

  /// null when the saved data is not a landmark
  static Landmark? fromJson(Object? json) {
    if (json
        case {
          'id': int id,
          'name': String name,
          'latitude': num latitude,
          'longitude': num longitude,
        }) {
      final lat = latitude.toDouble(), lon = longitude.toDouble();
      if (!lat.isFinite || !lon.isFinite) return null;
      final shown = json['visible'];
      return Landmark(
          id: id,
          name: name,
          latitude: lat,
          longitude: lon,
          visible: shown is bool ? shown : true);
    }
    return null;
  }
}
