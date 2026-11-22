import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';

void main() {
  test('lee campos conocidos y convierte claves dinámicas de forma segura', () {
    final order = OrderRecord.fromMap('p1', {
      'estado': 'entregado',
      'fecha': '2026-01-01T12:00:00.000Z',
      'total': 45.50,
      7: 'campo adicional',
    });

    expect(order.id, 'p1');
    expect(order.status, OrderStatus.delivered);
    expect(order.createdAt, DateTime.parse('2026-01-01T12:00:00.000Z'));
    expect(order.totalCents, 4550);
  });

  test('usa valores seguros para campos faltantes o inválidos', () {
    final order = OrderRecord.fromMap('p2', {
      'estado': false,
      'fecha': 9000000000000000000,
      'total': double.infinity,
      'totalCents': double.infinity,
    });

    expect(order.status, OrderStatus.paymentPending);
    expect(order.createdAt, isNull);
    expect(order.totalCents, 0);
  });
}
