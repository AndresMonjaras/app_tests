import 'dart:math';

import 'cafeteria_location.dart';

class DeliveryCoverage {
  const DeliveryCoverage({
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.approximate,
    required this.note,
  });

  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final bool approximate;
  final String note;

  static DeliveryCoverage? tryFrom(Object? value) {
    if (value is! Map) return null;
    final lat = parseCoordinate(value['centerLat']);
    final lng = parseCoordinate(value['centerLng']);
    final radius = parseCoordinate(value['radiusMeters']);
    final approximate = value['approximate'];
    final note = value['note'];
    if (lat == null ||
        lat.abs() > 90 ||
        lng == null ||
        lng.abs() > 180 ||
        radius == null ||
        radius <= 0 ||
        approximate is! bool ||
        note is! String ||
        note.trim().isEmpty) {
      return null;
    }
    return DeliveryCoverage(
      centerLat: lat,
      centerLng: lng,
      radiusMeters: radius,
      approximate: approximate,
      note: note.trim(),
    );
  }

  bool contains(double lat, double lng) {
    if (!lat.isFinite || lat.abs() > 90 || !lng.isFinite || lng.abs() > 180) {
      return false;
    }
    double radians(double degrees) => degrees * pi / 180;
    final halfLat = radians(centerLat - lat) / 2;
    final halfLng = radians(centerLng - lng) / 2;
    final a =
        pow(sin(halfLat), 2) +
        cos(radians(lat)) * cos(radians(centerLat)) * pow(sin(halfLng), 2);
    final distance = 2 * 6371000 * asin(sqrt(min(1, a)));
    return distance <= radiusMeters;
  }
}

class DeliveryLocation {
  const DeliveryLocation({
    required this.lat,
    required this.lng,
    required this.building,
    required this.room,
    required this.references,
  });

  final double lat;
  final double lng;
  final String building;
  final String room;
  final String references;
}
