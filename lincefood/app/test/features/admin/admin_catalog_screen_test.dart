import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_providers.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_screen.dart';

void main() {
  for (final size in const [
    Size(360, 800),
    Size(768, 1024),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    testWidgets('distribución en $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogEditorAccessProvider.overrideWith((ref) async => true),
            adminAccessProvider.overrideWith((ref) async => false),
            adminProductsProvider.overrideWith(
              (ref) => Stream.value([
                for (final name in ['Uno', 'Dos', 'Tres'])
                  Product(
                    id: name,
                    name: name,
                    categoryId: 'Comida',
                    priceCents: 100,
                    prepMinutes: 1,
                    demo: true,
                  ),
              ]),
            ),
          ],
          child: const MaterialApp(home: AdminCatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text('Uno'));
      final second = tester.getTopLeft(find.text('Dos'));
      if (size.width >= 1024) {
        expect(first.dy, second.dy);
        expect(second.dx, greaterThan(first.dx));
        expect(tester.getTopLeft(find.text('Tres')).dx, first.dx);
      } else {
        expect(first.dx, second.dx);
        expect(second.dy, greaterThan(first.dy));
      }
      final bounds = tester.getRect(find.byType(ListView));
      expect(bounds.width, size.width.clamp(0, 1100));
      expect(bounds.center.dx, size.width / 2);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'un falso claim admin no permite ver el catálogo de administración',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [adminAccessProvider.overrideWith((ref) async => false)],
          child: const MaterialApp(home: AdminCatalogScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('No tienes permiso para administrar el catálogo.'),
        findsOneWidget,
      );
      expect(find.text('Agregar producto'), findsNothing);
    },
  );
}
