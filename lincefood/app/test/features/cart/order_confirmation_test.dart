import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/cart/presentation/order_confirmation_dialog.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/domain/pickup_mode.dart';

final _cart = Cart([
  CartLine(
    product: Product(
      id: 'torta',
      name: 'Torta',
      categoryId: 'lunch',
      priceCents: 5000,
      prepMinutes: 8,
    ),
    quantity: 2,
  ),
]);

/// Abre el diálogo desde un botón y guarda el resultado en [holder].
Future<void> _pumpOpener(WidgetTester tester, List<bool?> holder) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                holder.add(
                  await showOrderConfirmationDialog(
                    context,
                    cart: _cart,
                    pickupMode: PickupMode.takeAway,
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra resumen, total y aviso de no cancelación', (
    tester,
  ) async {
    await _pumpOpener(tester, []);

    expect(find.text('Revisa tu pedido'), findsOneWidget);
    expect(find.text('2 productos'), findsOneWidget);
    expect(find.text('Recogida: Para llevar'), findsOneWidget);
    expect(
      find.textContaining('no podrás cambiarlo ni cancelarlo'),
      findsOneWidget,
    );
    expect(find.text('Confirmar y pagar'), findsOneWidget);
  });

  testWidgets('volver no confirma el pedido', (tester) async {
    final results = <bool?>[];
    await _pumpOpener(tester, results);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('confirmar y pagar devuelve verdadero', (tester) async {
    final results = <bool?>[];
    await _pumpOpener(tester, results);

    await tester.tap(find.text('Confirmar y pagar'));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });
}
