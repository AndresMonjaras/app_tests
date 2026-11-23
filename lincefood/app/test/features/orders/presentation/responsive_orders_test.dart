import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';
import 'package:lincefood_app/features/orders/presentation/orders_screen.dart';
import 'package:lincefood_app/features/orders/presentation/staff_orders_screen.dart';

void main() {
  for (final (size, columns) in [
    (const Size(360, 800), 1),
    (const Size(768, 1024), 1),
    (const Size(1280, 800), 2),
    (const Size(1920, 1080), 3),
  ]) {
    for (final staff in [false, true]) {
      final name = staff ? 'Cola del personal' : 'Mi ticket';
      testWidgets('$name a ${size.width} muestra $columns columnas', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final orders = List.generate(
          4,
          (i) => OrderRecord(
            id: 'p$i',
            folio: 'LF-$i',
            status: OrderStatus.paid,
            lines: [],
            createdAt: DateTime(2026, 1, 4 - i),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              staffPermissionProvider.overrideWith((_) async => true),
              ordersStreamProvider.overrideWith((_) => Stream.value(orders)),
              staffOrdersStreamProvider.overrideWith(
                (_) => Stream.value(orders),
              ),
            ],
            child: MaterialApp(
              home: staff ? const StaffOrdersScreen() : const OrdersScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Offset position(int i) =>
            tester.getTopLeft(find.text(staff ? 'Folio LF-$i' : 'LF-$i'));
        final first = position(0);
        for (var i = 1; i < columns; i++) {
          expect(position(i).dy, first.dy);
          expect(position(i).dx, greaterThan(position(i - 1).dx));
        }
        final scroll = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        if (columns == 1) {
          scroll.jumpTo(360);
          await tester.pump();
        }
        expect(position(columns).dx, first.dx);
        expect(position(columns).dy + scroll.pixels, greaterThan(first.dy));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
