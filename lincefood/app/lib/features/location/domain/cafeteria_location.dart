class CafeteriaLocation {
  const CafeteriaLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.address = '',
  });

  final double latitude;
  final double longitude;
  final String label;
  final String address;

  static CafeteriaLocation? tryFrom(Object? value) {
    if (value is! Map) return null;
    final latitude = _coordinate(value['latitude']);
    final longitude = _coordinate(value['longitude']);
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
    );
  }

  static double? _coordinate(Object? value) {
    if (value is! num) return null;
    final result = value.toDouble();
    return result.isFinite ? result : null;
  }
}
