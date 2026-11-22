import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/cart/presentation/cart_controller.dart';
import 'package:lincefood_app/features/cart/presentation/cart_screen.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/pickup_mode.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart'
    show
        orderClockProvider,
        ordersRepositoryProvider,
        staffPermissionProvider,
        uidActivoProvider;
import 'package:lincefood_app/features/orders/presentation/order_actions_controller.dart'
    show orderActionsProvider;
import 'package:lincefood_app/features/payments/domain/payment_gateway.dart';
import 'package:lincefood_app/features/payments/presentation/payment_providers.dart';

class _FakePaymentGateway implements PaymentGateway {
  _FakePaymentGateway({this.failPayment = false});

  final bool failPayment;
  String? createdOrderId;
  bool presented = false;

  @override
  Future<String> createPaymentIntent(String orderId) async {
    createdOrderId = orderId;
    return 'test-client-secret';
  }

  @override
  Future<void> presentPaymentSheet(String clientSecret) async {
    presented = true;
    if (failPayment) throw StateError('Pago cancelado');
  }
}

void main() {
  Future<ProviderContainer> openCart(
    WidgetTester tester, {
    required MemoryOrdersRepository repository,
    required _FakePaymentGateway gateway,
    required bool paymentsConfigured,
  }) async {
    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
        uidActivoProvider.overrideWithValue('uid-1'),
        staffPermissionProvider.overrideWith((ref) async => false),
        orderClockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        paymentGatewayProvider.overrideWithValue(gateway),
        paymentConfiguredProvider.overrideWithValue(paymentsConfigured),
      ],
    );
    container
        .read(cartControllerProvider.notifier)
        .addProduct(
          product: Product(id: 'cafe', name: 'Café', priceCents: 550),
          quantity: 2,
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    return container;
  }

  testWidgets('pago exitoso abre el ticket del pedido', (tester) async {
    final repository = MemoryOrdersRepository();
    final gateway = _FakePaymentGateway();
    final container = await openCart(
      tester,
      repository: repository,
      gateway: gateway,
      paymentsConfigured: true,
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);

    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar y pagar'));
    await tester.pumpAndSettle();
    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('Total a pagar'), findsOneWidget);

    await tester.tap(find.text('Pagar ahora'));
    await tester.pumpAndSettle();

    expect(gateway.createdOrderId, 'pedido-1');
    expect(gateway.presented, isTrue);
    expect(find.text('Mi ticket'), findsOneWidget);
    expect(find.text('LF-000001'), findsOneWidget);
  });

  testWidgets('la modalidad elegida llega al pedido y al resumen', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    final gateway = _FakePaymentGateway();
    final container = await openCart(
      tester,
      repository: repository,
      gateway: gateway,
      paymentsConfigured: true,
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);

    await tester.tap(find.text(PickupMode.takeAway.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();

    expect(find.text('Recogida: Para llevar'), findsOneWidget);
    expect(
      find.textContaining('no podrás cambiarlo ni cancelarlo'),
      findsOneWidget,
    );

    await tester.tap(find.text('Confirmar y pagar'));
    await tester.pumpAndSettle();

    expect(
      container.read(orderActionsProvider).order?.pickupMode,
      PickupMode.takeAway,
    );
    expect(find.text('Pago'), findsOneWidget);
  });

  testWidgets('pago cancelado deja el pedido pendiente y no abre el ticket', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    final gateway = _FakePaymentGateway(failPayment: true);
    final container = await openCart(
      tester,
      repository: repository,
      gateway: gateway,
      paymentsConfigured: true,
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);

    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar y pagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagar ahora'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      container.read(orderActionsProvider).order?.status,
      OrderStatus.paymentPending,
    );
    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('Mi ticket'), findsNothing);
  });

  testWidgets('sin configuración muestra mensaje y no llama al gateway', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    final gateway = _FakePaymentGateway();
    final container = await openCart(
      tester,
      repository: repository,
      gateway: gateway,
      paymentsConfigured: false,
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);

    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar y pagar'));
    await tester.pumpAndSettle();

    expect(find.text('Pagos no configurados'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(gateway.createdOrderId, isNull);
    expect(gateway.presented, isFalse);
  });
}
