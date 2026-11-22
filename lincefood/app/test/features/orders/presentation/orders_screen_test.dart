import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/app_router.dart';
import 'package:lincefood_app/app/app_theme.dart';
import 'package:lincefood_app/core/money/money.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';
import 'package:lincefood_app/features/orders/presentation/orders_screen.dart';

void main() {
  testWidgets('el ticket muestra folio, total y estado en cocina', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [
      OrderRecord(
        id: 'order-1',
        ownerUid: 'uid-1',
        folio: 'LF-000001',
        status: OrderStatus.preparing,
        lines: [
          CartLine(
            product: Product(id: 'cafe', name: 'Café', priceCents: 1299),
            quantity: 1,
          ),
        ],
        totalCents: 1299,
        createdAt: DateTime.utc(2026, 11, 22, 12),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          uidActivoProvider.overrideWithValue('uid-1'),
          orderClockProvider.overrideWith(
            (ref) => Stream.value(DateTime.utc(2026, 11, 22, 12, 12)),
          ),
        ],
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LF-000001'), findsOneWidget);
    expect(find.text(formatMoney(1299)), findsOneWidget);
    expect(find.text('1 unidad · ${formatMoney(1299)}'), findsOneWidget);
    expect(find.text('Pedido en preparación'), findsOneWidget);
    expect(find.text('Preparando tus alimentos'), findsOneWidget);
    expect(find.text('Pago confirmado'), findsOneWidget);
    expect(find.text('Recoger en cafetería'), findsOneWidget);
    expect(find.textContaining('Pedido a las'), findsOneWidget);
    expect(find.text('Hace 12 min'), findsOneWidget);
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('ticket a ${width.toInt()} px en ${brightness.name}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = MemoryOrdersRepository();
        addTearDown(repository.dispose);
        const orderId = 'pedido-1';
        void emit(OrderStatus status) {
          repository.setOrders('uid-1', [
            OrderRecord(
              id: orderId,
              status: status,
              folio: '#0058',
              lines: [
                CartLine(
                  product: Product(
                    id: 'torta',
                    name: 'Torta con ensalada y verduras de temporada',
                    priceCents: 6500,
                  ),
                  quantity: 1,
                ),
              ],
            ),
          ]);
        }

        emit(OrderStatus.paymentPending);
        RouteSettings? qrRoute;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ordersRepositoryProvider.overrideWithValue(repository),
              uidActivoProvider.overrideWithValue('uid-1'),
              orderClockProvider.overrideWith(
                (ref) => Stream.value(DateTime.utc(2026, 11, 22, 12)),
              ),
            ],
            child: MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.dark
                  : AppTheme.light,
              home: const OrdersScreen(),
              onGenerateRoute: (settings) {
                qrRoute = settings;
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('QR de prueba')),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final qr = find.text('Mostrar QR de recogida');
        expect(qr, findsNothing);
        expect(find.text('Pago confirmado'), findsNothing);
        expect(
          Theme.of(tester.element(find.text('#0058'))).brightness,
          brightness,
        );

        for (final status in [
          OrderStatus.paid,
          OrderStatus.confirmed,
          OrderStatus.preparing,
          OrderStatus.ready,
          OrderStatus.delivered,
        ]) {
          emit(status);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Pago confirmado'), findsOneWidget);
          expect(
            qr,
            status == OrderStatus.ready ? findsOneWidget : findsNothing,
          );

          if (status == OrderStatus.ready) {
            await tester.ensureVisible(qr);
            await tester.pumpAndSettle();
            await tester.tap(qr);
            await tester.pumpAndSettle();
            expect(qrRoute?.name, AppRouter.pickupQr);
            expect(qrRoute?.arguments, {'orderId': orderId});
            Navigator.of(tester.element(find.text('QR de prueba'))).pop();
            await tester.pumpAndSettle();
          }
        }
      });
    }
  }
}
