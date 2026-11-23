import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_providers.dart';
import 'package:lincefood_app/features/admin/presentation/admin_taxonomy_controller.dart';
import 'package:lincefood_app/features/admin/presentation/admin_taxonomy_providers.dart';
import 'package:lincefood_app/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_screen.dart';

class _Taxonomy extends Fake implements AdminTaxonomyController {
  final saved = <({String name, String? id})>[];
  final removed = <String>[];
  bool failDelete = false;

  @override
  Future<String> saveCategory(String name, {String? id}) async {
    saved.add((name: name, id: id));
    return id ?? 'new-category';
  }

  @override
  Future<void> removeCategory(String id) async {
    removed.add(id);
    if (failDelete) throw StateError('write failed');
  }
}

Future<_Taxonomy> _openCatalog(
  WidgetTester tester, {
  bool editor = true,
}) async {
  final catalog = InMemoryCatalogRepository([
    Product(id: 'cafe', name: 'Café', categoryId: 'drinks', priceCents: 2500),
  ]);
  final taxonomy = _Taxonomy();
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
        adminTaxonomyControllerProvider.overrideWithValue(taxonomy),
        adminCategoriesProvider.overrideWith(
          (ref) => Stream.value({'drinks': 'Bebidas calientes'}),
        ),
      ],
      child: const MaterialApp(home: CatalogScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return taxonomy;
}

Future<void> _chooseAction(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Opciones de la sección'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el editor ve la tarjeta nueva y las opciones de sección', (
    tester,
  ) async {
    await _openCatalog(tester);
    expect(find.text('Bebidas calientes'), findsOneWidget);
    expect(find.text('Nueva sección'), findsOneWidget);
    expect(find.byTooltip('Opciones de la sección'), findsOneWidget);
  });

  testWidgets('el cliente ve el catálogo sin controles de sección', (
    tester,
  ) async {
    await _openCatalog(tester, editor: false);
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Nueva sección'), findsNothing);
    expect(find.byTooltip('Opciones de la sección'), findsNothing);
  });

  testWidgets('Nueva sección guarda el nombre sin id', (tester) async {
    final taxonomy = await _openCatalog(tester);
    await tester.tap(find.text('Nueva sección'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Nueva sección'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre de la sección'),
      'Postres',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(taxonomy.saved, [(name: 'Postres', id: null)]);
  });

  testWidgets('Renombrar conserva el id de la sección', (tester) async {
    final taxonomy = await _openCatalog(tester);
    await _chooseAction(tester, 'Renombrar');
    final field = find.widgetWithText(TextField, 'Nombre de la sección');
    expect(
      tester.widget<TextField>(field).controller!.text,
      'Bebidas calientes',
    );
    await tester.enterText(field, 'Cafetería');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(taxonomy.saved, [(name: 'Cafetería', id: 'drinks')]);
  });

  testWidgets('Eliminar requiere confirmar la sección seleccionada', (
    tester,
  ) async {
    final taxonomy = await _openCatalog(tester);
    await _chooseAction(tester, 'Eliminar');
    expect(
      find.widgetWithText(AlertDialog, '¿Eliminar «Bebidas calientes»?'),
      findsOneWidget,
    );
    expect(taxonomy.removed, isEmpty);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(taxonomy.removed, isEmpty);
    await _chooseAction(tester, 'Eliminar');
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(taxonomy.removed, ['drinks']);
  });

  testWidgets('un fallo al eliminar muestra el error en un SnackBar', (
    tester,
  ) async {
    final taxonomy = await _openCatalog(tester);
    taxonomy.failDelete = true;
    await _chooseAction(tester, 'Eliminar');
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(taxonomy.removed, ['drinks']);
    expect(
      find.widgetWithText(
        SnackBar,
        'No se pudo guardar el cambio. Intenta de nuevo.',
      ),
      findsOneWidget,
    );
  });
}
