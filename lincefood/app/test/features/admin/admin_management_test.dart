import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/admin/presentation/admin_product_form.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';

void main() {
  test('precios exactos y límites sin desbordamiento', () {
    for (final entry in {
      '12,50': 1250,
      ' 12.5 ': 1250,
      '0': 0,
      '90071992547409.91': 9007199254740991,
      '00001.01': 101,
    }.entries) {
      expect(parseAdminPrice(entry.key), entry.value);
    }
    for (final value in [
      '',
      '-1',
      '1.001',
      '1e3',
      '1,2.3',
      '90071992547409.92',
      '99999999999999999999999999999999',
    ]) {
      expect(parseAdminPrice(value), isNull, reason: value);
    }
  });
  testWidgets('editar precio conserva datos y cambia variantes', (
    tester,
  ) async {
    Product? saved;
    final product = Product(
      id: 'coffee',
      name: 'Café',
      categoryId: 'Bebidas',
      priceCents: 1200,
      prepMinutes: 5,
      variants: [ProductVariant(label: 'Grande', priceCents: 2000)],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await showDialog<Product>(
                    context: context,
                    builder: (_) =>
                        AdminProductForm(product: product, priceOnly: true),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio en MXN'),
      '15,25',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio de variante en MXN'),
      '25.50',
    );
    await tester.tap(find.text('Guardar precio'));
    await tester.pumpAndSettle();
    expect(saved?.priceCents, 1525);
    expect(saved?.variants.single.priceCents, 2550);
    expect(saved?.prepMinutes, 5);
    expect(saved?.categoryId, 'Bebidas');
    expect(tester.takeException(), isNull);
  });
  testWidgets('producto inválido informa errores', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AdminProductForm())),
      ),
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un nombre.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
