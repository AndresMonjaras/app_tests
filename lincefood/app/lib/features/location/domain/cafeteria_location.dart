class CafeteriaLocation {
  const CafeteriaLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.address = '',
    this.hours = '',
    this.approximate = true,
  });

  final double latitude;
  final double longitude;
  final String label;
  final String address;
  final String hours;
  final bool approximate;

  static CafeteriaLocation? tryFrom(Object? value) {
    if (value is! Map) return null;
    final latitude = parseCoordinate(value['lat'] ?? value['latitude']);
    final longitude = parseCoordinate(value['lng'] ?? value['longitude']);
    final label = (value['label'] ?? '').toString().trim();
    if (latitude == null ||
        longitude == null ||
        label.isEmpty ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return CafeteriaLocation(
      latitude: latitude,
      longitude: longitude,
      label: label,
      address: (value['address'] ?? '').toString().trim(),
      hours: (value['hours'] ?? '').toString().trim(),
      approximate: value['approximate'] != false,
    );
  }
}

double? parseCoordinate(Object? value) {
  if (value is! num) return null;
  final result = value.toDouble();
  return result.isFinite ? result : null;
}
