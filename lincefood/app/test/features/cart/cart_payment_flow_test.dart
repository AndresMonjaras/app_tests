import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/app_router.dart';
import 'package:lincefood_app/features/cart/domain/cart.dart';
import 'package:lincefood_app/features/cart/presentation/cart_controller.dart';
import 'package:lincefood_app/features/cart/presentation/cart_screen.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_record.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/domain/pickup_mode.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart'
    show ordersRepositoryProvider, uidActivoProvider;
import 'package:lincefood_app/features/payments/domain/payment_gateway.dart';
import 'package:lincefood_app/features/payments/presentation/payment_providers.dart';

class _OrdersRepository extends MemoryOrdersRepository {
  int creations = 0;
  Completer<void>? creationGate;
  OrderRecord? createdOrder;

  @override
  Future<OrderRecord> createOrder({
    required String ownerUid,
    required Cart cart,
    required PickupMode pickupMode,
    required String idempotencyKey,
    DateTime? createdAt,
  }) async {
    creations++;
    await creationGate?.future;
    final order = await super.createOrder(
      ownerUid: ownerUid,
      cart: Cart([
        CartLine(
          product: Product(id: 'cafe', name: 'Café', priceCents: 3500),
          quantity: 1,
        ),
      ]),
      pickupMode: pickupMode,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
    );
    createdOrder = order;
    // La respuesta de createOrder aún no trae el precio del servidor.
    return OrderRecord(
      id: order.id,
      ownerUid: ownerUid,
      status: order.status,
      lines: cart.lines,
      pickupMode: pickupMode,
    );
  }
}

class _PaymentGateway implements PaymentGateway {
  Object? intentError;
  Object? sheetError;
  Completer<void>? sheetGate;
  final orderIds = <String>[];
  int opened = 0;

  @override
  Future<String> createPaymentIntent(String orderId) async {
    orderIds.add(orderId);
    if (intentError case final error?) throw error;
    return 'test-client-secret';
  }

  @override
  Future<void> presentPaymentSheet(String clientSecret) async {
    opened++;
    await sheetGate?.future;
    if (sheetError case final error?) throw error;
  }
}

void main() {
  late _OrdersRepository repository;
  late _PaymentGateway gateway;
  late ProviderContainer container;
  RouteSettings? trackingRoute;
  final initialPay = find.text(r'Pagar $65.00 MXN');
  final retryPay = find.text(r'Pagar $35.00 MXN');

  setUp(() {
    repository = _OrdersRepository();
    gateway = _PaymentGateway();
    trackingRoute = null;
  });

  Future<void> openCart(WidgetTester tester, {bool configured = true}) async {
    container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
        uidActivoProvider.overrideWithValue('uid-1'),
        paymentGatewayProvider.overrideWithValue(gateway),
        paymentConfiguredProvider.overrideWithValue(configured),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);
    container
        .read(cartControllerProvider.notifier)
        .addProduct(
          product: Product(id: 'cafe', name: 'Café', priceCents: 6500),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: const CartScreen(),
          onGenerateRoute: (settings) {
            trackingRoute = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Seguimiento')),
            );
          },
        ),
      ),
    );
  }

  testWidgets('un doble toque crea un pedido y un intento y abre seguimiento', (
    tester,
  ) async {
    repository.creationGate = Completer<void>();
    gateway.sheetGate = Completer<void>();
    await openCart(tester);
    await tester.tap(find.text(PickupMode.takeAway.label));
    await tester.pumpAndSettle();
    await tester.tap(initialPay);
    await tester.tap(initialPay);
    await tester.pump();

    expect(repository.creations, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    repository.creationGate!.complete();
    for (var frame = 0; frame < 10 && gateway.opened == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump();
    expect(gateway.orderIds, ['pedido-1']);
    expect(gateway.opened, 1);
    expect(find.text(r'$35.00 MXN'), findsNWidgets(2));

    gateway.sheetGate!.complete();
    await tester.pumpAndSettle();
    expect(trackingRoute?.name, AppRouter.orders);
    expect(trackingRoute?.arguments, {'orderId': 'pedido-1'});
    expect(find.text('Seguimiento'), findsOneWidget);
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
    expect(repository.createdOrder?.status, OrderStatus.paymentPending);
    expect(repository.createdOrder?.pickupMode, PickupMode.takeAway);
  });

  testWidgets('rechazo deja el pedido pendiente y reintenta con su mismo ID', (
    tester,
  ) async {
    gateway.sheetError = const PaymentDeclinedException();
    await openCart(tester);
    await tester.tap(initialPay);
    await tester.pumpAndSettle();

    expect(find.textContaining('Pago rechazado'), findsOneWidget);
    expect(repository.createdOrder?.status, OrderStatus.paymentPending);
    expect(trackingRoute, isNull);
    expect(retryPay, findsOneWidget);

    gateway.sheetError = null;
    await tester.tap(retryPay);
    await tester.pumpAndSettle();
    expect(repository.creations, 1);
    expect(gateway.orderIds, ['pedido-1', 'pedido-1']);
    expect(trackingRoute?.name, AppRouter.orders);
  });

  testWidgets('cerrar la hoja conserva el carrito sin mostrar error', (
    tester,
  ) async {
    gateway.sheetError = const PaymentCancelledException();
    await openCart(tester);
    await tester.tap(initialPay);
    await tester.pumpAndSettle();

    expect(find.text('Carrito'), findsOneWidget);
    expect(find.textContaining('Inténtalo'), findsNothing);
    expect(retryPay, findsOneWidget);
    expect(trackingRoute, isNull);
    expect(container.read(cartControllerProvider).isEmpty, isFalse);
    expect(repository.createdOrder?.status, OrderStatus.paymentPending);
  });

  testWidgets('sin conexión muestra un mensaje y permite reintentar', (
    tester,
  ) async {
    gateway.intentError = const PaymentNetworkException();
    await openCart(tester);
    await tester.tap(initialPay);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin conexión'), findsOneWidget);
    expect(gateway.opened, 0);
    expect(trackingRoute, isNull);
    gateway.intentError = null;
    await tester.tap(retryPay);
    await tester.pumpAndSettle();

    expect(repository.creations, 1);
    expect(gateway.orderIds, ['pedido-1', 'pedido-1']);
    expect(trackingRoute?.name, AppRouter.orders);
  });

  testWidgets('sin configuración el botón de pago queda deshabilitado', (
    tester,
  ) async {
    await openCart(tester, configured: false);

    expect(find.text('Pagos no configurados'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.creations, 0);
    expect(gateway.orderIds, isEmpty);
  });
}
