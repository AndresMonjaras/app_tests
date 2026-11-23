import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_screen.dart';

void main() {
  for (final size in const [
    Size(360, 800),
    Size(768, 1024),
    Size(1024, 800),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    testWidgets('Distribución del catálogo a ${size.width} × ${size.height}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogProductsProvider.overrideWith(
              (ref) => Stream.value([
                for (var i = 0; i < 4; i++)
                  Product(id: 'p$i', name: 'Producto $i', priceCents: 100),
              ]),
            ),
          ],
          child: const MaterialApp(home: CatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(CustomScrollView));
      expect(viewport.width, size.width.clamp(0, 1280));
      expect(viewport.center.dx, size.width / 2);
      expect(find.text('Buscar en el menú'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
      await tester.pumpAndSettle();
      final columns = size.width < 1024
          ? 1
          : size.width == 1024
          ? 2
          : 3;
      Rect card(int i) => tester.getRect(
        find.ancestor(
          of: find.text('Producto $i'),
          matching: find.byType(Card),
        ),
      );
      for (var i = 1; i < columns; i++) {
        expect(card(i).top, card(0).top);
        expect(card(i).left, greaterThan(card(i - 1).right));
      }
      expect(card(columns).left, card(0).left);
      expect(card(columns).top, greaterThan(card(0).top));
      if (columns == 1) expect(card(0).width, size.width - 32);
      expect(tester.takeException(), isNull);
    });
  }
}
