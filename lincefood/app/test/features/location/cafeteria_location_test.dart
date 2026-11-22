import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lincefood_app/features/location/domain/cafeteria_location.dart';
import 'package:lincefood_app/features/location/domain/delivery_location.dart';
import 'package:lincefood_app/features/location/presentation/cafeteria_location_screen.dart';
import 'package:lincefood_app/features/location/presentation/delivery_location_picker.dart';
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
    expect(find.byType(GoogleMap), findsNothing);
  });

  testWidgets('conserva dirección visible si Maps aún no está configurado', (
    tester,
  ) async {
    final location = const CafeteriaLocation(
      latitude: 20,
      longitude: -99,
      label: 'Punto de recogida',
      address: 'Edificio de cafetería',
      hours: 'Lunes a viernes, 7:30–19:00',
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

    expect(find.byType(GoogleMap), findsNothing);
    expect(find.text('Cómo llegar'), findsOneWidget);
    expect(find.text('Ubicación aproximada'), findsOneWidget);
    expect(find.text('Lunes a viernes, 7:30–19:00'), findsOneWidget);
    expect(find.text('Punto de recogida'), findsOneWidget);
    expect(find.text('Edificio de cafetería'), findsOneWidget);
  });

  test('lee el formato actual y conserva ubicaciones anteriores', () {
    final location = CafeteriaLocation.tryFrom({
      'lat': 20.54146,
      'lng': -100.81192,
      'label': 'Cafetería · Campus II',
      'hours': 'Lunes a viernes',
      'approximate': false,
    });
    expect(location?.latitude, 20.54146);
    expect(location?.longitude, -100.81192);
    expect(location?.hours, 'Lunes a viernes');
    expect(location?.approximate, false);
  });

  const coverage = DeliveryCoverage(
    centerLat: 20.54146,
    centerLng: -100.81192,
    radiusMeters: 350,
    approximate: true,
    note: 'Validar límites reales del Campus II',
  );

  test('el radio distingue puntos dentro y fuera de cobertura', () {
    expect(coverage.contains(20.54346, -100.81192), true);
    expect(coverage.contains(20.54146, -100.80692), false);
    expect(coverage.contains(380.54146, -100.81192), false);
  });

  testWidgets('muestra mapa nativo, marcador y cobertura provisional', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cafeteriaLocationProvider.overrideWith(
            (ref) => Stream.value(
              const CafeteriaLocation(
                latitude: 20.54146,
                longitude: -100.81192,
                label: 'Cafetería · Campus II',
                approximate: false,
              ),
            ),
          ),
          deliveryCoverageProvider.overrideWith(
            (ref) => Stream.value(coverage),
          ),
        ],
        child: const MaterialApp(
          home: CafeteriaLocationScreen(mapsEnabled: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers.single.position, const LatLng(20.54146, -100.81192));
    expect(map.circles.single.radius, 350);
    expect(map.myLocationEnabled, false);
    expect(find.textContaining('Radio provisional'), findsOneWidget);
    expect(find.text('Ubicación aproximada'), findsNothing);
  });

  testWidgets('el selector requiere cobertura vigente antes de confirmar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var serverAllows = false;
    var validations = 0;
    DeliveryLocation? confirmed;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryCoverageProvider.overrideWith(
            (ref) => Stream.value(coverage),
          ),
          deliveryLocationValidatorProvider.overrideWith(
            (ref) => (lat, lng) async {
              expect(lat, coverage.centerLat);
              expect(lng, coverage.centerLng);
              validations++;
              return serverAllows;
            },
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeliveryLocationPicker(
                mapsEnabled: true,
                onConfirmed: (location) => confirmed = location,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final confirm = find.widgetWithText(FilledButton, 'Confirmar ubicación');
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    map.onTap!(const LatLng(21, -100));
    await tester.pumpAndSettle();
    expect(
      find.text('El punto está fuera de la cobertura de entrega.'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    final inside = LatLng(coverage.centerLat, coverage.centerLng);
    map.onTap!(inside);
    await tester.pumpAndSettle();
    expect(
      tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.single.position,
      inside,
    );

    await tester.enterText(find.byType(TextFormField).first, 'Edificio A');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirmed, isNull);
    expect(
      find.text('El punto está fuera de la cobertura de entrega vigente.'),
      findsOneWidget,
    );

    serverAllows = true;
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirmed?.building, 'Edificio A');
    expect(validations, 2);
  });
}
