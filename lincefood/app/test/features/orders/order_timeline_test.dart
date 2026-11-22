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

  testWidgets('dibuja el timeline y expone los pasos accesibles', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(OrderStatus.preparing));
    await tester.pumpAndSettle();

    expect(find.text('Pagado'), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('En preparación'), findsOneWidget);
    expect(find.text('Listo para recoger'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    expect(find.byKey(const Key('order-timeline-painter')), findsOneWidget);
    expect(find.bySemanticsLabel('Pagado, completado'), findsOneWidget);
    expect(
      find.bySemanticsLabel('En preparación, paso actual'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Entregado, pendiente'), findsOneWidget);

    final currentText = tester.widget<Text>(find.text('En preparación'));
    expect(currentText.style?.fontWeight, FontWeight.bold);
    semantics.dispose();
  });

  testWidgets('entrega anuncia los pasos anteriores como completos', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(OrderStatus.delivered));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Listo para recoger, completado'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Entregado, paso actual'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('no marca pasos para pago pendiente ni incidente', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final status in [OrderStatus.paymentPending, OrderStatus.incident]) {
      await tester.pumpWidget(_app(status));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Pagado, pendiente'), findsOneWidget);
      expect(find.bySemanticsLabel('Entregado, pendiente'), findsOneWidget);
    }
    semantics.dispose();
  });

  testWidgets('usa colores del tema oscuro para los pasos pendientes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(OrderStatus.confirmed, theme: ThemeData.dark()),
    );
    await tester.pumpAndSettle();

    final pendingText = tester.widget<Text>(find.text('Entregado'));
    expect(pendingText.style?.color, isNotNull);
  });

  testWidgets('anima el progreso cuando avanza el estado', (tester) async {
    await tester.pumpWidget(_app(OrderStatus.confirmed));
    await tester.pumpAndSettle();
    final initialPainter = tester
        .widget<CustomPaint>(find.byKey(const Key('order-timeline-painter')))
        .painter;

    await tester.pumpWidget(_app(OrderStatus.ready));
    await tester.pump(const Duration(milliseconds: 300));
    final movingPainter = tester
        .widget<CustomPaint>(find.byKey(const Key('order-timeline-painter')))
        .painter;
    expect(movingPainter, isNot(same(initialPainter)));
    await tester.pumpAndSettle();
  });
}
