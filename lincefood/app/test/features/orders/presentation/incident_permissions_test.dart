import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/order_actions_controller.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';

ProviderContainer _contenedor(
  MemoryOrdersRepository repository, {
  required bool isAdmin,
}) {
  final container = ProviderContainer(
    overrides: [
      ordersRepositoryProvider.overrideWithValue(repository),
      adminPermissionProvider.overrideWith((ref) async => isAdmin),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('el personal no puede marcar una incidencia', () async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [
      OrderRecord(id: 'order-1', status: OrderStatus.paid, lines: const []),
    ]);
    final container = _contenedor(repository, isAdmin: false);

    await container
        .read(orderActionsProvider.notifier)
        .reportIncident(orderId: 'order-1', reason: 'Problema operativo');

    expect(
      container.read(orderActionsProvider).errorMessage,
      'Solo administración puede marcar incidencias.',
    );
    expect(
      (await repository.watchPaidOrdersForStaff().first).single.status,
      OrderStatus.paid,
    );
  });

  test('un administrador marca y luego resuelve una incidencia', () async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [
      OrderRecord(
        id: 'order-1',
        status: OrderStatus.preparing,
        lines: const [],
      ),
    ]);
    final container = _contenedor(repository, isAdmin: true);
    final actions = container.read(orderActionsProvider.notifier);

    await actions.reportIncident(
      orderId: 'order-1',
      reason: 'Cobro inconsistente',
    );
    expect(container.read(orderActionsProvider).errorMessage, isNull);
    expect(
      (await repository.watchPaidOrdersForStaff().first).single.status,
      OrderStatus.incident,
    );

    await actions.resolveIncident(
      orderId: 'order-1',
      resolution: 'Reembolso manual',
    );
    expect(container.read(orderActionsProvider).errorMessage, isNull);
    expect(await repository.watchPaidOrdersForStaff().first, isEmpty);
  });

  test('no se puede resolver una incidencia que no existe', () async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [
      OrderRecord(id: 'order-1', status: OrderStatus.paid, lines: const []),
    ]);
    final container = _contenedor(repository, isAdmin: true);

    await container
        .read(orderActionsProvider.notifier)
        .resolveIncident(orderId: 'order-1', resolution: 'Reembolso manual');

    expect(
      container.read(orderActionsProvider).errorMessage,
      'El pedido no está en incidencia.',
    );
  });

  test('el cliente no puede pasar un pedido pagado a incidencia', () async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [
      OrderRecord(id: 'order-1', status: OrderStatus.paid, lines: const []),
    ]);

    final container = _contenedor(repository, isAdmin: false);
    await container
        .read(orderActionsProvider.notifier)
        .reportIncident(orderId: 'order-1', reason: 'Problema operativo');

    expect(container.read(orderActionsProvider).writeResults, isEmpty);
    expect(
      (await repository.watchPaidOrdersForStaff().first).single.status,
      OrderStatus.paid,
    );
  });
}
