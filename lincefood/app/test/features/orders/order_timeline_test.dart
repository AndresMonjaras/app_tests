import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/app_theme.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/order_timeline.dart';

Widget _app(
  OrderStatus status, {
  ThemeData? theme,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(body: OrderTimeline(currentStatus: status)),
  );
}

void main() {
  test('el cliente solo puede cancelar mientras el pago está pendiente', () {
    expect(canCustomerCancel(OrderStatus.paymentPending), isTrue);
    expect(canCustomerCancel(OrderStatus.paid), isFalse);
    expect(canCustomerCancel(OrderStatus.confirmed), isFalse);
    expect(canCustomerCancel(OrderStatus.preparing), isFalse);
    expect(canCustomerCancel(OrderStatus.ready), isFalse);
    expect(canCustomerCancel(OrderStatus.delivered), isFalse);
    expect(canCustomerCancel(OrderStatus.incident), isFalse);
  });

  const steps = [
    (OrderStatus.confirmed, 'Recibido', Icons.assignment_turned_in, 0.125),
    (OrderStatus.preparing, 'En cocina', Icons.soup_kitchen, 0.375),
    (OrderStatus.ready, 'Listo', Icons.restaurant, 0.625),
    (OrderStatus.delivered, 'Entregado', Icons.inventory_2, 1.0),
  ];

  for (var index = 0; index < steps.length; index++) {
    final (status, label, icon, value) = steps[index];
    testWidgets('activa $label y atenúa los pasos pendientes', (tester) async {
      await tester.pumpWidget(_app(status, theme: AppTheme.dark));
      final active = find.bySemanticsLabel('$label, paso actual');
      final activeIcon = tester.widget<Icon>(
        find.descendant(of: active, matching: find.byIcon(icon)),
      );
      expect(activeIcon.color, AppTheme.dark.colorScheme.primary);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, value);

      for (final (_, priorLabel, _, _) in steps.take(index)) {
        final complete = find.bySemanticsLabel('$priorLabel, completado');
        final check = tester.widget<Icon>(
          find.descendant(of: complete, matching: find.byIcon(Icons.check)),
        );
        expect(check.color, AppTheme.successColor(Brightness.dark));
      }
      for (final (_, nextLabel, _, _) in steps.skip(index + 1)) {
        final pending = find.bySemanticsLabel('$nextLabel, pendiente');
        final opacity = tester.widget<Opacity>(
          find.descendant(of: pending, matching: find.byType(Opacity)),
        );
        expect(opacity.opacity, 0.4);
      }

      final first = tester.getCenter(find.text('Recibido'));
      final last = tester.getCenter(find.text('Entregado'));
      expect(last.dy, first.dy);
      expect(last.dx, greaterThan(first.dx));
      expect(find.text('Pagado'), findsNothing);
    });
  }

  testWidgets('los estados fuera de preparación y entrega no activan pasos', (
    tester,
  ) async {
    for (final status in [
      OrderStatus.paymentPending,
      OrderStatus.paid,
      OrderStatus.incident,
      OrderStatus.rejected,
    ]) {
      await tester.pumpWidget(_app(status));
      for (final (_, label, _, _) in steps) {
        expect(find.bySemanticsLabel('$label, pendiente'), findsOneWidget);
      }
    }
  });

  testWidgets('anima el cambio una vez durante 300 ms', (tester) async {
    await tester.pumpWidget(_app(OrderStatus.confirmed));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(_app(OrderStatus.preparing));
    await tester.pump(const Duration(milliseconds: 150));

    final progress = find.byType(LinearProgressIndicator);
    expect(
      tester.widget<LinearProgressIndicator>(progress).value,
      allOf(greaterThan(0.125), lessThan(0.375)),
    );
    final active = find.bySemanticsLabel('En cocina, paso actual');
    final scale = find.descendant(of: active, matching: find.byType(Transform));
    expect(
      tester.widget<Transform>(scale).transform.entry(0, 0),
      greaterThan(1),
    );

    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<LinearProgressIndicator>(progress).value, 0.375);
    expect(
      tester.widget<Transform>(scale).transform.entry(0, 0),
      closeTo(1, 0.001),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('respeta la preferencia de reducir movimiento', (tester) async {
    await tester.pumpWidget(
      _app(OrderStatus.confirmed, disableAnimations: true),
    );
    await tester.pumpWidget(_app(OrderStatus.ready, disableAnimations: true));
    await tester.pump();
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 0.625);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
