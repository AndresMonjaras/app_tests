import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/location/domain/cafeteria_location.dart';
import 'package:lincefood_app/features/location/presentation/cafeteria_location_screen.dart';
import 'package:lincefood_app/features/location/presentation/location_providers.dart';

void main() {
  test('acepta solo coordenadas finitas dentro de rango', () {
    final location = CafeteriaLocation.tryFrom({
      'latitude': 20.0,
      'longitude': -99.0,
      'label': 'Punto de recogida',
      'address': 'Edificio de cafetería',
    });

    expect(location?.latitude, 20.0);
    expect(location?.longitude, -99.0);
    expect(location?.label, 'Punto de recogida');
    expect(
      CafeteriaLocation.tryFrom({
        'latitude': 95,
        'longitude': -99,
        'label': 'Ubicación inválida',
      }),
      isNull,
    );
    expect(
      CafeteriaLocation.tryFrom({
        'latitude': double.infinity,
        'longitude': -99,
        'label': 'Ubicación inválida',
      }),
      isNull,
    );
  });

  testWidgets('no inventa marcador si faltan coordenadas verificadas', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cafeteriaLocationProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: CafeteriaLocationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ubicación pendiente de confirmar'), findsOneWidget);
    expect(find.byType(CafeteriaLocationScreen), findsOneWidget);
    expect(find.textContaining('coordenadas verificadas'), findsOneWidget);
  });

  testWidgets('conserva dirección visible si Maps aún no está configurado', (
    tester,
  ) async {
    final location = const CafeteriaLocation(
      latitude: 20,
      longitude: -99,
      label: 'Punto de recogida',
      address: 'Edificio de cafetería',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cafeteriaLocationProvider.overrideWith(
            (ref) => Stream.value(location),
          ),
        ],
        child: const MaterialApp(
          home: CafeteriaLocationScreen(mapsEnabled: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mapa pendiente de configuración'), findsOneWidget);
    expect(find.text('Punto de recogida'), findsOneWidget);
    expect(find.text('Edificio de cafetería'), findsOneWidget);
  });
}
