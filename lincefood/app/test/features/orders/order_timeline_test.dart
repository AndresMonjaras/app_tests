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
  test('el cliente solo puede cancelar mientras el pago está pendiente', () {
    expect(canCustomerCancel(OrderStatus.paymentPending), isTrue);
    for (final status in OrderStatus.values.skip(1)) {
      expect(canCustomerCancel(status), isFalse);
    }
  });

  testWidgets('muestra los pasos y resalta el actual', (tester) async {
    await tester.pumpWidget(_app(OrderStatus.preparing));

    expect(find.text('Pagado'), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('En preparación'), findsOneWidget);
    expect(find.text('Listo para recoger'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

    final currentText = tester.widget<Text>(find.text('En preparación'));
    expect(currentText.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('entrega completa todos los pasos previos', (tester) async {
    await tester.pumpWidget(_app(OrderStatus.delivered));

    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });

  testWidgets('no marca pasos para pago pendiente ni incidente', (tester) async {
    for (final status in [OrderStatus.paymentPending, OrderStatus.incident]) {
      await tester.pumpWidget(_app(status));

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    }
  });

  testWidgets('usa colores del tema oscuro para los pasos pendientes',
      (tester) async {
    await tester.pumpWidget(_app(OrderStatus.confirmed, theme: ThemeData.dark()));

    final pendingText = tester.widget<Text>(find.text('Entregado'));
    expect(pendingText.style?.color, isNotNull);
  });
}
