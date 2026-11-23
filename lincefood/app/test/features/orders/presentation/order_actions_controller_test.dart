import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/domain/pickup_mode.dart';
import 'package:lincefood_app/features/orders/presentation/order_actions_controller.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';

void main() {
  test(
    'crea un pedido pendiente sin cambiar su estado desde el cliente',
    () async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      final container = ProviderContainer(
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final cart = Cart([
        CartLine(
          product: Product(id: 'cafe', name: 'Café', priceCents: 550),
          quantity: 2,
        ),
      ]);

      final order = await container
          .read(orderActionsProvider.notifier)
          .submitOrder(
            ownerUid: 'uid-1',
            cart: cart,
            pickupMode: PickupMode.inStore,
          );

      expect(order?.status, OrderStatus.paymentPending);
      expect(order?.totalCents, 1100);
      expect(
        container.read(orderActionsProvider).writeResults.map((result) {
          return result.succeeded;
        }),
        [true],
      );
      expect(
        (await repository.watchOrdersFor('uid-1').first).single.status,
        OrderStatus.paymentPending,
      );
    },
  );

  test('guarda en Riverpod el rechazo de creación del pedido', () async {
    final repository = _BlockedOrdersRepository();
    addTearDown(repository.dispose);
    final container = ProviderContainer(
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(orderActionsProvider.notifier)
        .submitOrder(
          ownerUid: 'uid-1',
          cart: Cart([
            CartLine(
              product: Product(id: 'cafe', name: 'Café', priceCents: 550),
              quantity: 1,
            ),
          ]),
          pickupMode: PickupMode.takeAway,
        );

    final state = container.read(orderActionsProvider);
    expect(result, isNull);
    expect(
      state.errorMessage,
      'Las reglas actuales no permiten crear pedidos.',
    );
    expect(state.writeResults, hasLength(1));
    expect(state.writeResults.single.succeeded, isFalse);
  });

  test('un cliente no puede cambiar el estado de un pedido', () async {
    final repository = MemoryOrdersRepository();
    repository.setOrders('uid-1', [
      OrderRecord(id: 'order-1', status: OrderStatus.paid, lines: const []),
    ]);
    addTearDown(repository.dispose);
    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
        staffPermissionProvider.overrideWith((ref) async => false),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(orderActionsProvider.notifier)
        .updateOrderStatus(orderId: 'order-1', status: OrderStatus.preparing);

    expect(
      (await repository.watchOrdersFor('uid-1').first).single.status,
      OrderStatus.paid,
    );
    expect(
      container.read(orderActionsProvider).errorMessage,
      'Solo el personal puede cambiar el estado.',
    );
    expect(container.read(orderActionsProvider).writeResults, isEmpty);
  });
}

class _BlockedOrdersRepository extends MemoryOrdersRepository {
  @override
  Future<OrderRecord> createOrder({
    required String ownerUid,
    required Cart cart,
    required PickupMode pickupMode,
    required String idempotencyKey,
    DateTime? createdAt,
  }) async {
    throw StateError('Las reglas actuales no permiten crear pedidos.');
  }
}
