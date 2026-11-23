import 'dart:async';

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
  testWidgets('solo los pedidos terminados se ocultan y se pueden restaurar', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = StreamController<Set<String>>.broadcast();
    addTearDown(repository.dispose);
    addTearDown(changes.close);
    final saved = <String>{};
    const uid = 'uid-1';
    OrderRecord order(String id, OrderStatus status, {bool cancelled = false}) {
      return OrderRecord(
        id: id,
        folio: 'LF-$id',
        status: status,
        lines: [],
        isCancelled: cancelled,
      );
    }

    repository.setOrders(uid, [
      order('done', OrderStatus.delivered),
      order('ready', OrderStatus.ready),
      order('rejected', OrderStatus.rejected),
      order('cancelled', OrderStatus.paymentPending, cancelled: true),
    ]);

    Future<void> openHistory() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersRepositoryProvider.overrideWithValue(repository),
            uidActivoProvider.overrideWithValue(uid),
            hiddenOrderIdsProvider.overrideWith((ref, user) async* {
              expect(user, uid);
              yield Set.of(saved);
              yield* changes.stream;
            }),
            setOrderHiddenProvider.overrideWithValue((user, id, hidden) async {
              expect(user, uid);
              hidden ? saved.add(id) : saved.remove(id);
              changes.add(Set.of(saved));
            }),
          ],
          child: const MaterialApp(home: OrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> swipeAndConfirm() async {
      await tester.drag(
        find.byKey(const ValueKey('done')).first,
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('¿Ocultar pedido?'), findsOneWidget);
      await tester.tap(find.text('Ocultar'));
      await tester.pumpAndSettle();
    }

    await openHistory();
    expect(find.byType(Dismissible), findsNWidgets(3));
    expect(
      find.ancestor(
        of: find.text('LF-ready'),
        matching: find.byType(Dismissible),
      ),
      findsNothing,
    );

    await swipeAndConfirm();
    expect(find.text('LF-done'), findsNothing);
    expect(saved, {'done'});
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(find.text('LF-done'), findsOneWidget);
    expect(saved, isEmpty);

    await swipeAndConfirm();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await openHistory();
    expect(find.text('LF-done'), findsNothing);
    expect(find.text('LF-ready'), findsOneWidget);
  });

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

  testWidgets('el ticket muestra detalle y mojarritas decorativas', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    addTearDown(repository.dispose);
    repository.setOrders('uid-1', [
      OrderRecord(
        id: 'pedido-1',
        status: OrderStatus.confirmed,
        folio: '#0058',
        createdAt: DateTime.utc(2026, 11, 22, 12),
        lines: [
          CartLine(
            product: Product(id: 'torta', name: 'Torta', priceCents: 6500),
            quantity: 2,
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          uidActivoProvider.overrideWithValue('uid-1'),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artículos'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('¡Gracias por comer con Lincefood!'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
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
        final qr = find.text('Ver QR');
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
          // El QR se ve desde que el pedido esta pagado hasta que esta listo.
          final muestraQr = status != OrderStatus.delivered;
          expect(qr, muestraQr ? findsOneWidget : findsNothing);

          if (status == OrderStatus.ready) {
            await tester.ensureVisible(qr);
            await tester.pumpAndSettle();
            await tester.tap(qr);
            await tester.pumpAndSettle();
            expect(qrRoute?.name, AppRouter.pickupQr);
            expect(qrRoute?.arguments, {
              'orderId': orderId,
              'requireBiometrics': true,
            });
            Navigator.of(tester.element(find.text('QR de prueba'))).pop();
            await tester.pumpAndSettle();
          }
        }
      });
    }
  }
}
