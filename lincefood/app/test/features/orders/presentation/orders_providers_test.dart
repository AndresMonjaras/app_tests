import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';

class _UidTestNotifier extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void cambiar(String? uid) => state = uid;
}

final _uidTestProvider = NotifierProvider<_UidTestNotifier, String?>(
  _UidTestNotifier.new,
);

void main() {
  test('sin usuario activo emite una lista vacía', () async {
    final container = ProviderContainer(
      overrides: [uidActivoProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(ordersStreamProvider, (_, _) {});
    addTearDown(subscription.close);

    expect(await container.read(ordersStreamProvider.future), isEmpty);
  });

  test('usuario activo recibe sus pedidos del repositorio', () async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('u1', [
      OrderRecord(id: 'p1', status: OrderStatus.paid, lines: const []),
    ]);
    final container = ProviderContainer(
      overrides: [
        uidActivoProvider.overrideWithValue('u1'),
        ordersRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(ordersStreamProvider, (_, _) {});
    addTearDown(subscription.close);

    final orders = await container.read(ordersStreamProvider.future);
    expect(orders.map((order) => order.id), ['p1']);
  });

  test('cambiar el UID activo cambia la lista de pedidos', () async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('u1', [
      OrderRecord(id: 'p1', status: OrderStatus.paid, lines: const []),
    ]);
    repository.setOrders('u2', [
      OrderRecord(id: 'p2', status: OrderStatus.paid, lines: const []),
      OrderRecord(id: 'p3', status: OrderStatus.delivered, lines: const []),
    ]);
    final container = ProviderContainer(
      overrides: [
        uidActivoProvider.overrideWith((ref) => ref.watch(_uidTestProvider)),
        ordersRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final segundaLista = Completer<List<OrderRecord>>();
    final subscription = container.listen(ordersStreamProvider, (_, next) {
      next.whenData((orders) {
        if (orders.length == 2 && !segundaLista.isCompleted) {
          segundaLista.complete(orders);
        }
      });
    });
    addTearDown(subscription.close);

    expect(await container.read(ordersStreamProvider.future), hasLength(1));
    container.read(_uidTestProvider.notifier).cambiar('u2');
    expect(
      await segundaLista.future.timeout(const Duration(seconds: 1)),
      hasLength(2),
    );
  });
}
