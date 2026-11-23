import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/presentation/admin_product_form.dart';
import 'package:lincefood_app/features/admin/presentation/admin_taxonomy_providers.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';

void main() {
  testWidgets(
    'el formulario sigue las unidades en vivo y conserva la del producto',
    (tester) async {
      final units = StreamController<Map<String, CatalogUnit>>();
      addTearDown(units.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [adminUnitsProvider.overrideWith((ref) => units.stream)],
          child: MaterialApp(
            home: Scaffold(
              body: AdminProductForm(
                product: Product(
                  id: 'p',
                  name: 'Pan',
                  priceCents: 100,
                  portionUnit: 'caja',
                ),
              ),
            ),
          ),
        ),
      );
      units.add({'caja': (label: 'Cajas', symbol: 'cj')});
      await tester.pumpAndSettle();
      DropdownButton<String> dropdown() => tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      expect(dropdown().value, 'caja');
      units.add({'kg': (label: 'Kilogramos', symbol: 'kg')});
      await tester.pumpAndSettle();
      expect(dropdown().value, isNull);
      expect(dropdown().items!.map((item) => item.value), ['kg']);
    },
  );
}
