import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';
import 'package:lincefood_app/features/orders/presentation/orders_screen.dart';
import 'package:lincefood_app/features/orders/presentation/staff_orders_screen.dart';

OrderRecord _pedido(String id, OrderStatus status) {
  return OrderRecord(
    id: id,
    ownerUid: 'uid-1',
    folio: 'LF-$id',
    status: status,
    lines: [
      CartLine(
        product: Product(id: 'cafe', name: 'Café', priceCents: 500),
        quantity: 1,
      ),
    ],
    totalCents: 500,
    createdAt: DateTime.utc(2026, 11, 22, 12),
  );
}

Future<void> _montarTicket(
  WidgetTester tester,
  MemoryOrdersRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
        uidActivoProvider.overrideWithValue('uid-1'),
        orderClockProvider.overrideWith(
          (ref) => Stream.value(DateTime.utc(2026, 11, 22, 12, 5)),
        ),
      ],
      child: const MaterialApp(home: OrdersScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final status in [
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.delivered,
    OrderStatus.incident,
  ]) {
    testWidgets('el cliente no ve cancelar ni editar en ${status.code}', (
      tester,
    ) async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      repository.setOrders('uid-1', [_pedido('1', status)]);

      await _montarTicket(tester, repository);

      expect(find.textContaining('Cancelar'), findsNothing);
      expect(find.textContaining('cancelar'), findsNothing);
      expect(find.textContaining('Editar'), findsNothing);
      expect(find.textContaining('Modificar'), findsNothing);
    });
  }

  for (final status in [OrderStatus.paid, OrderStatus.confirmed]) {
    testWidgets('el cliente puede cancelar en ${status.code} tras confirmar', (
      tester,
    ) async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      repository.setOrders('uid-1', [_pedido('1', status)]);

      await _montarTicket(tester, repository);

      expect(find.text('Cancelar pedido'), findsOneWidget);
    });
  }

  testWidgets('el personal confirma un pedido pagado paso a paso', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [_pedido('1', OrderStatus.paid)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          staffPermissionProvider.overrideWith((ref) async => true),
          adminPermissionProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: StaffOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marcar incidencia'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(
      (await tester.runAsync(() => repository.watchOrdersFor('uid-1').first))!
          .single
          .status,
      OrderStatus.confirmed,
    );
  });

  testWidgets('solo un administrador ve y usa la acción de incidencia', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [_pedido('1', OrderStatus.ready)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          staffPermissionProvider.overrideWith((ref) async => true),
          adminPermissionProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: StaffOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marcar incidencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Producto agotado'));
    await tester.pumpAndSettle();

    final order = (await tester.runAsync(
      () => repository.watchPaidOrdersForStaff().first,
    ))!.single;
    expect(order.status, OrderStatus.incident);
  });

  testWidgets('un pedido cancelado no muestra acciones ni pasos', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [_pedido('1', OrderStatus.paid).cancel()]);

    await _montarTicket(tester, repository);

    expect(find.text('Pedido cancelado'), findsOneWidget);
    expect(find.text('Cancelar pedido'), findsNothing);
  });
}
