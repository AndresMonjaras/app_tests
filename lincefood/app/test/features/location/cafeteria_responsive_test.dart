import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lincefood_app/features/location/presentation/cafeteria_location_screen.dart';

void main() {
  for (final size in const [
    Size(360, 800),
    Size(768, 1024),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    for (final maps in [false, true]) {
      testWidgets('Distribución a ${size.width} con mapsEnabled=$maps', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: CafeteriaLocationScreen(mapsEnabled: maps),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final desktop = size.width >= 1024;
        final first = find.text('Cafetería 1 ITC');
        final banner = find.textContaining('disponible en las 3 cafeterías');
        final firstRect = tester.getRect(first);
        if (maps) {
          final mapRect = tester.getRect(find.byType(GoogleMap));
          if (desktop) {
            expect(find.byType(PageView), findsNothing);
            expect(firstRect.right, lessThan(mapRect.left));
            expect(mapRect.width, greaterThan(380));
            expect(mapRect.right, (size.width + 1280) / 2 - 12);
            final second = find.text('Cafetería 2 ITC');
            await tester.ensureVisible(second);
            await tester.tap(second);
            await tester.pumpAndSettle();
            final container = ProviderScope.containerOf(tester.element(second));
            expect(container.read(selectedCafeteriaProvider), 1);
          } else {
            final carousel = tester.getRect(find.byType(PageView));
            expect(carousel.height, 190);
            expect(mapRect.bottom - carousel.bottom, 12);
            expect(tester.getRect(banner).bottom, lessThan(mapRect.top));
          }
        } else {
          final setup = tester.getRect(
            find.text('Mapa pendiente de configuración'),
          );
          if (desktop) {
            expect(setup.right, lessThan(firstRect.left));
            expect(tester.getRect(banner).bottom, lessThan(setup.top));
          } else {
            expect(setup.bottom, lessThan(firstRect.top));
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
