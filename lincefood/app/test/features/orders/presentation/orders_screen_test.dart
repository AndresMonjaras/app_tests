import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/core/money/money.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';
import 'package:lincefood_app/features/orders/presentation/orders_screen.dart';

void main() {
  testWidgets('el ticket muestra folio, total y estado en cocina', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [
      OrderRecord(
        id: 'order-1',
        ownerUid: 'uid-1',
        folio: 'LF-000001',
        status: OrderStatus.preparing,
        lines: [
          CartLine(
            product: Product(id: 'cafe', name: 'Café', priceCents: 1299),
            quantity: 1,
          ),
        ],
        totalCents: 1299,
        createdAt: DateTime.utc(2026, 11, 22, 12),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          uidActivoProvider.overrideWithValue('uid-1'),
          orderClockProvider.overrideWith(
            (ref) => Stream.value(DateTime.utc(2026, 11, 22, 12, 12)),
          ),
        ],
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Folio LF-000001'), findsOneWidget);
    expect(find.text(formatMoney(1299)), findsNWidgets(2));
    expect(find.text('Estado: En cocina'), findsOneWidget);
    expect(find.text('Hace 12 min'), findsOneWidget);
  });
}
