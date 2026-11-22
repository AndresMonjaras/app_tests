import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/core/errors/domain_exception.dart';
import 'package:lincefood_app/core/money/money.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/domain/pickup_mode.dart';

void main() {
  test('calcula total en centavos y serializa los campos de RTDB', () {
    final product = Product(
      id: 'cafe-americano',
      name: 'Café americano',
      priceCents: 1250,
    );
    final cart = Cart([CartLine(product: product, quantity: 2)]);
    final order = OrderRecord(
      id: 'order-1',
      ownerUid: 'uid-1',
      folio: 'LF-000001',
      status: OrderStatus.paymentPending,
      lines: cart.lines,
      pickupMode: PickupMode.takeAway,
      createdAt: DateTime.utc(2026, 11, 22, 12),
      totalCents: cart.totalCents,
    );

    final map = order.toMap();
    final line = (map['lines'] as List).single as Map;

    expect(order.totalCents, 2500);
    expect(formatMoney(order.totalCents), r'$25.00 MXN');
    expect(map['ownerUid'], 'uid-1');
    expect(map['status'], 'payment_pending');
    expect(map['totalCents'], 2500);
    expect(map['pickupMode'], 'take_away');
    expect(line['quantity'], 2);
    expect(line['priceCents'], 1250);
    expect((line['product'] as Map)['name'], 'Café americano');
  });

  test('recupera líneas y campos del pedido desde RTDB', () {
    final order = OrderRecord.fromMap('order-2', {
      'ownerUid': 'uid-2',
      'folio': 'LF-ABC123',
      'status': 'preparing',
      'pickupMode': 'in_store',
      'createdAt': 1795363200000,
      'totalCents': 1800,
      'lines': [
        {
          'product': {'id': 'te', 'name': 'Té'},
          'variant': 'Grande',
          'quantity': 2,
          'priceCents': 900,
        },
      ],
    });

    expect(order.ownerUid, 'uid-2');
    expect(order.displayFolio, 'LF-ABC123');
    expect(order.status, OrderStatus.preparing);
    expect(order.pickupMode, PickupMode.inStore);
    expect(order.lines.single.product.name, 'Té');
    expect(order.lines.single.variant?.label, 'Grande');
    expect(order.lines.single.totalCents, 1800);
  });

  test('permite avanzar y rechaza volver de entregado a en cocina', () {
    final pending = OrderRecord(
      id: 'order-3',
      status: OrderStatus.paymentPending,
      lines: const [],
    );
    final paid = pending.transitionTo(OrderStatus.paid);
    final preparing = paid.transitionTo(OrderStatus.preparing);
    final delivered = preparing.transitionTo(OrderStatus.delivered);

    expect(delivered.status, OrderStatus.delivered);
    expect(
      () => delivered.transitionTo(OrderStatus.preparing),
      throwsA(isA<DomainException>()),
    );
  });
}
