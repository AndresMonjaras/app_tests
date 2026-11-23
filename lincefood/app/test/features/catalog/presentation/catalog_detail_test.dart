import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_screen.dart';
import 'package:lincefood_app/features/media/presentation/menu_image_providers.dart';

void main() {
  final mainProduct = Product(
    id: 'cafe',
    name: 'Café de olla',
    categoryId: 'drinks',
    priceCents: 2500,
    description: 'Café con especias.',
    ingredients: ['Café', 'Canela'],
    variants: [
      ProductVariant(label: 'Chico', priceCents: 2500, isAvailable: false),
      ProductVariant(label: 'Grande', priceCents: 3500),
    ],
    complements: [ProductVariant(label: 'Leche', priceCents: 1000)],
  );
  final related = Product(
    id: 'agua',
    name: 'Agua',
    categoryId: 'drinks',
    priceCents: 1500,
    description: 'Agua natural.',
  );
  final archived = Product(
    id: 'jugo',
    name: 'Jugo archivado',
    categoryId: 'drinks',
    priceCents: 2500,
    archived: true,
  );

  Future<void> openCatalog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(
            InMemoryCatalogRepository([mainProduct, related, archived]),
          ),
          menuImagesEnabledProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const CatalogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('foto local está disponible en el bundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final path = menuImageAssetPath('cafe')!;
    final bytes = await rootBundle.load(path);
    expect(bytes.lengthInBytes, inInclusiveRange(1, 150000));
    expect(bytes.getUint16(0), 0xffd8);
  });

  testWidgets(
    'detalle oscuro con foto, ingredientes y productos relacionados',
    (tester) async {
      await openCatalog(tester);
      expect(find.text('Jugo archivado'), findsNothing);
      await tester.tap(find.text('Café de olla'));
      await tester.pumpAndSettle();

      // La descripción aparece tanto en la tarjeta como en el detalle.
      expect(find.text('Café con especias.'), findsNWidgets(2));
      expect(find.text('Café, Canela'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Complementos opcionales'), findsOneWidget);
      expect(find.text('Leche'), findsOneWidget);
      expect(find.text('Productos relacionados'), findsOneWidget);
      final image = tester.widget<Image>(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.height == 200,
        ),
      );
      expect(image.image, isA<AssetImage>());
      final exhausted = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Chico'),
      );
      expect(exhausted.enabled, isFalse);

      await tester.tap(find.widgetWithText(ListTile, 'Agua'));
      await tester.pumpAndSettle();
      expect(find.text('Agua natural.'), findsNWidgets(2));
    },
  );

  testWidgets('la variante agotada está deshabilitada en el selector', (
    tester,
  ) async {
    await openCatalog(tester);
    await tester.tap(find.byTooltip('Elegir variante'));
    await tester.pumpAndSettle();

    final exhausted = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Chico'),
    );
    final available = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Grande'),
    );
    expect(exhausted.enabled, isFalse);
    expect(exhausted.onTap, isNull);
    expect(available.onTap, isNotNull);
  });
}
