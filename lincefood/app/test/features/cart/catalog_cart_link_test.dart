import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/cart/presentation/cart_controller.dart';
import 'package:lincefood_app/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_screen.dart';

void main() {
  testWidgets('agrega al carrito el producto y variante seleccionados', (
    tester,
  ) async {
    final product = Product(
      id: 'cafe',
      name: 'Café',
      priceCents: 0,
      variants: [ProductVariant(label: 'Grande', priceCents: 1500)],
    );
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          InMemoryCatalogRepository([product]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Elegir variante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grande'));
    await tester.pumpAndSettle();

    final cart = container.read(cartControllerProvider);
    expect(cart.lines.single.variant?.label, 'Grande');
    expect(cart.totalCents, 1500);
  });
}
