import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/data/admin_catalog_repository.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_providers.dart';
import 'package:lincefood_app/features/admin/presentation/admin_product_form.dart';
import 'package:lincefood_app/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_screen.dart';

final cafe = Product(
  id: 'cafe',
  name: 'Café de olla',
  categoryId: 'drinks',
  priceCents: 2500,
);

class _Catalog extends InMemoryCatalogRepository
    implements AdminCatalogRepository {
  _Catalog(super.products);

  final removed = <String, Product>{};
  bool? confirmedDelete;
  bool failDelete = false;
  Completer<void>? pendingDelete;

  @override
  Future<void> upsertProduct(Product product) async {
    final products = await fetchProducts();
    updateProducts([...products.where((p) => p.id != product.id), product]);
  }

  @override
  Future<void> deleteProduct(
    String productId, {
    required bool confirmed,
  }) async {
    confirmedDelete = confirmed;
    if (failDelete) throw StateError('write failed');
    final products = await fetchProducts();
    removed[productId] = products.singleWhere((p) => p.id == productId);
    updateProducts(products.where((p) => p.id != productId).toList());
    await pendingDelete?.future;
  }

  @override
  Future<void> restoreProduct(String productId) async {
    await upsertProduct(removed.remove(productId)!);
  }

  @override
  Future<void> updateProductPrice(String productId, int priceCents) =>
      throw UnimplementedError();

  @override
  Future<void> setProductAvailability(String productId, bool available) =>
      throw UnimplementedError();
}

Future<void> _openCatalog(
  WidgetTester tester,
  _Catalog catalog, {
  required bool editor,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(catalog.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogEditorAccessProvider.overrideWith((ref) async => editor),
        catalogRepositoryProvider.overrideWithValue(catalog),
        adminCatalogRepositoryProvider.overrideWithValue(catalog),
      ],
      child: const MaterialApp(home: CatalogScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _swipeLeft(WidgetTester tester) async {
  await tester.drag(find.text(cafe.name), const Offset(-550, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'el editor abre el detalle y edita desde la esquina superior derecha',
    (tester) async {
      final catalog = _Catalog([cafe]);
      await _openCatalog(tester, catalog, editor: true);
      expect(find.text('Agregar producto'), findsOneWidget);
      final card = tester.getRect(find.widgetWithText(Card, cafe.name));
      final pencil = find.byTooltip('Editar producto');
      final button = tester.getRect(pencil);
      expect(button.top - card.top, inInclusiveRange(0, 12));
      expect(card.right - button.right, inInclusiveRange(0, 16));

      await tester.tap(find.text(cafe.name));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(AdminProductForm), findsNothing);
      Navigator.pop(tester.element(find.byType(BottomSheet)));
      await tester.pumpAndSettle();

      await tester.tap(pencil);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.widget<AdminProductForm>(find.byType(AdminProductForm)).product,
        cafe,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Café frío',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Café frío'), findsOneWidget);
      expect((await catalog.fetchProducts()).single.id, cafe.id);
    },
  );

  testWidgets('el editor puede agregar el primer producto', (tester) async {
    final catalog = _Catalog([]);
    await _openCatalog(tester, catalog, editor: true);
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AdminProductForm>(find.byType(AdminProductForm)).product,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Agua',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Categoría (ID)'),
      'drinks',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio en MXN'),
      '15',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Agua'), findsOneWidget);
    expect((await catalog.fetchProducts()).single.name, 'Agua');
  });

  testWidgets('el cliente solo accede al detalle desde la tarjeta', (
    tester,
  ) async {
    final catalog = _Catalog([cafe]);
    await _openCatalog(tester, catalog, editor: false);
    expect(find.byTooltip('Editar producto'), findsNothing);
    expect(find.text('Agregar producto'), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
    await _swipeLeft(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(catalog.confirmedDelete, isNull);
    await tester.tap(find.text(cafe.name));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('eliminar exige confirmación y Deshacer restaura el producto', (
    tester,
  ) async {
    final catalog = _Catalog([cafe]);
    await _openCatalog(tester, catalog, editor: true);
    await _swipeLeft(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text(cafe.name), findsOneWidget);
    expect(catalog.confirmedDelete, isNull);

    catalog.pendingDelete = Completer<void>();
    await _swipeLeft(tester);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(catalog.confirmedDelete, isTrue);
    expect(find.text(cafe.name), findsNothing);
    expect(find.text('Deshacer'), findsNothing);

    catalog.pendingDelete!.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(find.text(cafe.name), findsOneWidget);
    expect((await catalog.fetchProducts()).single.id, cafe.id);
  });

  testWidgets('si falla la eliminación, la tarjeta sigue disponible', (
    tester,
  ) async {
    final catalog = _Catalog([cafe])..failDelete = true;
    await _openCatalog(tester, catalog, editor: true);
    await _swipeLeft(tester);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo eliminar el producto.'), findsOneWidget);
    expect(find.text('Deshacer'), findsNothing);
    await tester.tap(find.text(cafe.name));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
