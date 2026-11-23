class CafeteriaMapPlace {
  const CafeteriaMapPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.details,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String details;
}

const cafeteriaMapPlaces = [
  CafeteriaMapPlace(
    id: 'cafeteria-1',
    name: 'Cafetería 1 ITC',
    latitude: 20.5380588,
    longitude: -100.8188993,
    details: 'Campus I · Edificio C · Abre lunes 7:00 a.m. · 3.6 (25 reseñas)',
  ),
  CafeteriaMapPlace(
    id: 'cafeteria-2',
    name: 'Cafetería 2 ITC',
    latitude: 20.536255,
    longitude: -100.8175037,
    details: r'Av. Irrigación 5 · Abre lunes 7:30 a.m. · 3.6 (357) · $1–$100 por persona',
  ),
  CafeteriaMapPlace(
    id: 'cafeteria-3',
    name: 'Cafetería 3 ITC',
    latitude: 20.5409871,
    longitude: -100.8128506,
    details: 'Campus II · Edificio J · Antonio García Cubas 127',
  ),
];
