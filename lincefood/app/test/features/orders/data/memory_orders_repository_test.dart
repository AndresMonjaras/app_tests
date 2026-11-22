import 'package:lincefood_app/core/errors/domain_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';

void main() {
  group('MemoryOrdersRepository', () {
    test('emite una lista vacía si el usuario no tiene pedidos', () async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);

      expect(await repository.watchOrdersFor('u1').first, isEmpty);
    });

    test('emite los pedidos precargados del usuario', () async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      repository.setOrders('u1', [
        OrderRecord(
          id: 'p1',
          status: OrderStatus.paymentPending,
          lines: const [],
        ),
        OrderRecord(id: 'p2', status: OrderStatus.delivered, lines: const []),
      ]);

      final orders = await repository.watchOrdersFor('u1').first;
      expect(orders.map((order) => order.id), ['p1', 'p2']);
    });

    test('no mezcla pedidos de usuarios distintos', () async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      repository.setOrders('u1', [
        OrderRecord(id: 'p1', status: OrderStatus.paid, lines: const []),
      ]);

      expect(await repository.watchOrdersFor('u2').first, isEmpty);
    });

    test('notifica cambios a los suscriptores activos', () async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      final emissions = <List<OrderRecord>>[];
      final subscription = repository
          .watchOrdersFor('u1')
          .listen(emissions.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(emissions, hasLength(1));
      expect(emissions.single, isEmpty);

      repository.setOrders('u1', [
        OrderRecord(id: 'p1', status: OrderStatus.paid, lines: const []),
      ]);
      await pumpEventQueue();
      expect(emissions.last.map((order) => order.id), ['p1']);
    });

    test('emite los pedidos pagados y sus cambios al personal', () async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      final emissions = <List<OrderRecord>>[];
      final subscription = repository.watchPaidOrdersForStaff().listen(
        emissions.add,
      );
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      repository.setOrders('u1', [
        OrderRecord(id: 'p1', status: OrderStatus.paid, lines: const []),
        OrderRecord(
          id: 'p2',
          status: OrderStatus.paymentPending,
          lines: const [],
        ),
      ]);
      await pumpEventQueue();
      expect(emissions.last.map((order) => order.id), ['p1']);

      await repository.updateOrderStatus('p1', OrderStatus.confirmed);
      await pumpEventQueue();
      expect(emissions.last.single.status, OrderStatus.confirmed);
    });

    test('no permite saltar pasos en el flujo del personal', () async {
      final repository = MemoryOrdersRepository();
      addTearDown(repository.dispose);
      repository.setOrders('u1', [
        OrderRecord(id: 'p1', status: OrderStatus.paid, lines: const []),
      ]);

      await expectLater(
        repository.updateOrderStatus('p1', OrderStatus.preparing),
        throwsA(isA<DomainException>()),
      );
      expect(
        (await repository.watchOrdersFor('u1').first).single.status,
        OrderStatus.paid,
      );
    });

    test('rechaza operaciones después de disponer el repositorio', () {
      final repository = MemoryOrdersRepository();
      repository.dispose();

      expect(() => repository.watchOrdersFor('u1'), throwsStateError);
      expect(() => repository.setOrders('u1', const []), throwsStateError);
    });

    test(
      'no crea un controlador si se dispone antes de escuchar el stream',
      () async {
        final repository = MemoryOrdersRepository();
        final stream = repository.watchOrdersFor('u1');
        repository.dispose();

        await expectLater(stream, emitsError(isA<StateError>()));
      },
    );
  });
}
