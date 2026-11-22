import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';

void main() {
  test('el personal avanza un paso a la vez desde pagado hasta listo', () {
    final steps = <OrderStatus>[];
    var status = OrderStatus.paid;
    while (status.nextStaffStep != null) {
      status = status.nextStaffStep!;
      steps.add(status);
    }

    expect(steps, [
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
    ]);
  });

  test('el personal no puede marcar listo como entregado desde el panel', () {
    expect(OrderStatus.ready.nextStaffStep, isNull);
  });

  test('pago pendiente e incidencia no tienen siguiente paso del personal', () {
    expect(OrderStatus.paymentPending.nextStaffStep, isNull);
    expect(OrderStatus.incident.nextStaffStep, isNull);
    expect(OrderStatus.delivered.nextStaffStep, isNull);
  });

  test('solo los estados pagados y activos pueden pasar a incidencia', () {
    expect(OrderStatus.paid.allowsIncident, isTrue);
    expect(OrderStatus.confirmed.allowsIncident, isTrue);
    expect(OrderStatus.preparing.allowsIncident, isTrue);
    expect(OrderStatus.ready.allowsIncident, isTrue);
    expect(OrderStatus.paymentPending.allowsIncident, isFalse);
    expect(OrderStatus.delivered.allowsIncident, isFalse);
    expect(OrderStatus.incident.allowsIncident, isFalse);
  });
}
