// Flujos T05, T06, T07, T08, T17 y T18 del plan C.5.
// Usan repositorios en memoria y dobles de pago; no tocan Firebase, Stripe ni red.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lincefood_app/features/cart/presentation/cart_controller.dart';
import 'package:lincefood_app/features/cart/presentation/cart_screen.dart';
import 'package:lincefood_app/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_screen.dart';
import 'package:lincefood_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/domain/order_status.dart';
import 'package:lincefood_app/features/orders/presentation/order_actions_controller.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart'
    show
        orderClockProvider,
        ordersRepositoryProvider,
        staffPermissionProvider,
        uidActivoProvider;
import 'package:lincefood_app/features/payments/data/in_memory_payment_gateway.dart';
import 'package:lincefood_app/features/payments/domain/payment_gateway.dart';
import 'package:lincefood_app/features/payments/presentation/payment_providers.dart';
import 'package:lincefood_app/features/plans/domain/service_plan.dart';
import 'package:lincefood_app/features/plans/presentation/plans_providers.dart';
import 'package:lincefood_app/features/plans/presentation/plans_screen.dart';

final _menu = [
  Product(
    id: 'cafe',
    name: 'Café',
    categoryId: 'Bebidas',
    priceCents: 550,
    prepMinutes: 3,
  ),
  Product(
    id: 'torta',
    name: 'Torta',
    categoryId: 'Comidas',
    priceCents: 5000,
    prepMinutes: 8,
    imagePath: 'menu/torta/v1.jpg',
  ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T05: onboarding muestra los tres pasos y permite elegir tema', (
    tester,
  ) async {
    ThemeMode? chosen;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onThemeChanged: (mode) => chosen = mode,
          onCompleted: () => completed = true,
        ),
      ),
    );

    expect(find.text('Pide antes de tu descanso'), findsOneWidget);
    expect(find.text('Paga de forma segura'), findsOneWidget);
    expect(find.text('Recoge cuando esté listo'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro').last);
    await tester.pumpAndSettle();
    expect(chosen, ThemeMode.dark);

    await tester.tap(find.text('Comenzar'));
    expect(completed, isTrue);
  });

  testWidgets(
    'T06: el menú se muestra sin foto cuando Storage está desactivado',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              InMemoryCatalogRepository(_menu),
            ),
          ],
          child: const MaterialApp(home: CatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Torta'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('T07: pago de prueba exitoso crea el pedido y abre el ticket', (
    tester,
  ) async {
    final repository = MemoryOrdersRepository();
    final container = await _openCart(
      tester,
      repository: repository,
      gateway: const InMemoryPaymentGateway(simulateSuccessfulPayments: true),
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);

    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagar ahora'));
    await tester.pumpAndSettle();

    expect(find.text('Mi ticket'), findsOneWidget);
    expect(find.text('Folio LF-000001'), findsOneWidget);
  });

  testWidgets(
    'T08: pago rechazado deja el pedido pendiente y no llega a cocina',
    (tester) async {
      final repository = MemoryOrdersRepository();
      final container = await _openCart(
        tester,
        repository: repository,
        gateway: const InMemoryPaymentGateway(
          simulateSuccessfulPayments: false,
        ),
      );
      addTearDown(container.dispose);
      addTearDown(repository.dispose);

      await tester.tap(find.text('Confirmar pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pagar ahora'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        container.read(orderActionsProvider).order?.status,
        OrderStatus.paymentPending,
      );
      expect(find.text('Mi ticket'), findsNothing);
    },
  );

  testWidgets('T17: los tres planes se comparan con el plan actual', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMembershipProvider.overrideWith(
            (ref) => Stream<Membership?>.value(null),
          ),
        ],
        child: const MaterialApp(home: PlansScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan actual: Básico.'), findsOneWidget);
    expect(find.text('Campus Plus'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Campus Pro'), 300);
    expect(find.text('Campus Pro'), findsOneWidget);
  });

  for (final size in const [Size(360, 740), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('T18: el catálogo no desborda en ${size.width.toInt()} px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              InMemoryCatalogRepository(_menu),
            ),
          ],
          child: const MaterialApp(home: CatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Torta'),
        200,
        scrollable: find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Torta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<ProviderContainer> _openCart(
  WidgetTester tester, {
  required MemoryOrdersRepository repository,
  required PaymentGateway gateway,
}) async {
  final container = ProviderContainer(
    overrides: [
      ordersRepositoryProvider.overrideWithValue(repository),
      uidActivoProvider.overrideWithValue('uid-1'),
      staffPermissionProvider.overrideWith((ref) async => false),
      orderClockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
      paymentGatewayProvider.overrideWithValue(gateway),
      paymentConfiguredProvider.overrideWithValue(true),
    ],
  );
  container
      .read(cartControllerProvider.notifier)
      .addProduct(product: _menu.first, quantity: 2);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CartScreen()),
    ),
  );
  return container;
}
