import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/core/errors/domain_exception.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/data/realtime_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/domain/pickup_mode.dart';

void main() {
  test('exige una instancia de Realtime Database para leer pedidos', () {
    final repository = RealtimeOrdersRepository();

    expect(() => repository.watchOrdersFor('u1'), throwsStateError);
  });

  test(
    'createOrder envía líneas sin precios ni totales al callable falso',
    () async {
      final calls = <String, Map<String, Object?>>{};
      final variant = ProductVariant(label: 'Mediana', priceCents: 1700);
      final product = Product(
        id: 'torta',
        name: 'Torta',
        priceCents: 1200,
        variants: [variant],
      );
      final repository = RealtimeOrdersRepository(
        callable: (name, data) async {
          calls[name] = data;
          return {'orderId': 'ORDER00000000000001', 'folio': 'LF-00000001'};
        },
      );

      final order = await repository.createOrder(
        ownerUid: 'user-1',
        cart: Cart([CartLine(product: product, variant: variant, quantity: 2)]),
        pickupMode: PickupMode.takeAway,
        createdAt: DateTime(2026, 11, 22),
      );

      final data = calls['createOrder']!;
      final lines = data['lines'] as List;
      final line = lines.single as Map;
      expect(lines, [
        {'productId': 'torta', 'variantLabel': 'Mediana', 'quantity': 2},
      ]);
      expect(line.keys.toSet(), {'productId', 'variantLabel', 'quantity'});
      expect(data.containsKey('totalCents'), isFalse);
      expect(data.containsKey('ownerUid'), isFalse);
      expect(data['pickupMode'], 'take_away');
      expect(order.id, 'ORDER00000000000001');
      expect(order.totalCents, 3400);
    },
  );

  test(
    'updateOrderStatus envía el pedido y estado al callable falso',
    () async {
      final calls = <String, Map<String, Object?>>{};
      final repository = RealtimeOrdersRepository(
        callable: (name, data) async {
          calls[name] = data;
          return {
            'orderId': 'order-1',
            'order': {
              'ownerUid': 'user-1',
              'status': 'preparing',
              'pickupMode': 'take_away',
              'totalCents': 3400,
              'lines': [
                {
                  'productId': 'torta',
                  'productName': 'Torta',
                  'variantLabel': 'Mediana',
                  'unitPriceCents': 1700,
                  'quantity': 2,
                },
              ],
            },
          };
        },
      );

      final order = await repository.updateOrderStatus(
        'order-1',
        OrderStatus.preparing,
      );

      expect(calls['updateOrderStatus'], {
        'orderId': 'order-1',
        'status': 'preparing',
      });
      expect(order.status, OrderStatus.preparing);
      expect(order.id, 'order-1');
    },
  );

  test('muestra en español el error del callable', () async {
    final repository = RealtimeOrdersRepository(
      callable: (name, data) async => throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Solo el personal puede actualizar el estado de un pedido.',
      ),
    );

    await expectLater(
      repository.updateOrderStatus('order-1', OrderStatus.preparing),
      throwsA(
        isA<DomainException>().having(
          (error) => error.message,
          'message',
          'Solo el personal puede actualizar el estado de un pedido.',
        ),
      ),
    );
  });

  test(
    'rejectOrder envía el folio y la nota, y lee el pedido rechazado',
    () async {
      final repository = RealtimeOrdersRepository(
        callable: (name, data) async {
          expect(name, 'rejectOrder');
          expect(data, {'orderId': 'order-1', 'reason': 'Café agotado'});
          return {
            'order': {'status': 'rejected', 'rejectionReason': 'Café agotado'},
          };
        },
      );

      final order = await repository.rejectOrder('order-1', '  Café agotado  ');

      expect(order.status, OrderStatus.rejected);
      expect(order.rejectionReason, 'Café agotado');
    },
  );
}
