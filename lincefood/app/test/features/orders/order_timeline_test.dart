import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/order_timeline.dart';

Widget _app(OrderStatus status, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: OrderTimeline(currentStatus: status)),
  );
}

void main() {
  test('el cliente puede cancelar hasta que el pedido entra a cocina', () {
    expect(canCustomerCancel(OrderStatus.paymentPending), isTrue);
    expect(canCustomerCancel(OrderStatus.paid), isTrue);
    expect(canCustomerCancel(OrderStatus.confirmed), isTrue);
    expect(canCustomerCancel(OrderStatus.preparing), isFalse);
    expect(canCustomerCancel(OrderStatus.ready), isFalse);
    expect(canCustomerCancel(OrderStatus.delivered), isFalse);
    expect(canCustomerCancel(OrderStatus.incident), isFalse);
  });

  testWidgets('muestra los pasos y resalta el actual', (tester) async {
    await tester.pumpWidget(_app(OrderStatus.preparing));

    expect(find.text('Pagado'), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('En cocina'), findsOneWidget);
    expect(find.text('Listo para recoger'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    expect(find.byKey(const Key('order-timeline-painter')), findsOneWidget);
    expect(find.bySemanticsLabel('En cocina, paso actual'), findsOneWidget);

    final currentText = tester.widget<Text>(find.text('En cocina'));
    expect(currentText.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('entrega completa todos los pasos previos', (tester) async {
    await tester.pumpWidget(_app(OrderStatus.delivered));

    expect(
      find.bySemanticsLabel('Listo para recoger, completado'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Entregado, paso actual'), findsOneWidget);
  });

  testWidgets('no marca pasos para pago pendiente ni incidente', (
    tester,
  ) async {
    for (final status in [OrderStatus.paymentPending, OrderStatus.incident]) {
      await tester.pumpWidget(_app(status));

      expect(find.bySemanticsLabel('En cocina, pendiente'), findsOneWidget);
    }
  });

  testWidgets('usa colores del tema oscuro para los pasos pendientes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(OrderStatus.confirmed, theme: ThemeData.dark()),
    );

    final pendingText = tester.widget<Text>(find.text('Entregado'));
    expect(pendingText.style?.color, isNotNull);
  });
}
