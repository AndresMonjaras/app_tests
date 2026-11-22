import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/app_theme.dart';
import 'package:lincefood_app/features/cart/presentation/cart_controller.dart';
import 'package:lincefood_app/features/cart/presentation/cart_screen.dart';
import 'package:lincefood_app/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_screen.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart'
    show
        orderClockProvider,
        ordersRepositoryProvider,
        staffPermissionProvider,
        uidActivoProvider;
import 'package:lincefood_app/features/payments/domain/payment_gateway.dart';
import 'package:lincefood_app/features/payments/presentation/payment_providers.dart';
import 'package:lincefood_app/shared/widgets/fixed_bottom_bar.dart';

// Productos de cuatro categorías para probar la cuadrícula.
final _productos = [
  Product(id: 'cafe', name: 'Café', priceCents: 550, categoryId: 'Bebidas'),
  Product(id: 'flan', name: 'Flan', priceCents: 900, categoryId: 'Postres'),
  Product(id: 'papas', name: 'Papas', priceCents: 700, categoryId: 'Snacks'),
  Product(id: 'sopa', name: 'Sopa', priceCents: 1200, categoryId: 'Comidas'),
];

Future<void> _abrirCatalogo(
  WidgetTester tester, {
  required Size tamano,
  double escalaTexto = 1,
  ThemeMode modo = ThemeMode.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(
        InMemoryCatalogRepository(_productos),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: modo,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escalaTexto)),
          child: child!,
        ),
        home: const CatalogScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('en 360 px la cuadricula de categorias tiene dos columnas', (
    tester,
  ) async {
    await _abrirCatalogo(tester, tamano: const Size(360, 800));

    // Orden alfabético: Bebidas, Comidas, Postres, Snacks.
    final bebidas = tester.getTopLeft(find.text('Bebidas'));
    final comidas = tester.getTopLeft(find.text('Comidas'));
    final postres = tester.getTopLeft(find.text('Postres'));

    expect(comidas.dy, bebidas.dy);
    expect(postres.dx, bebidas.dx);
    expect(postres.dy, greaterThan(bebidas.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('en 1280 px la cuadricula de categorias usa cuatro columnas', (
    tester,
  ) async {
    await _abrirCatalogo(tester, tamano: const Size(1280, 800));

    final y = tester.getTopLeft(find.text('Bebidas')).dy;
    for (final etiqueta in ['Postres', 'Snacks', 'Comidas']) {
      expect(tester.getTopLeft(find.text(etiqueta)).dy, y);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('no hay desbordamiento con texto ampliado en 360 px', (
    tester,
  ) async {
    await _abrirCatalogo(tester, tamano: const Size(360, 800), escalaTexto: 2);

    expect(find.text('Explora el menú'), findsOneWidget);
    expect(find.text('Bebidas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el catalogo se pinta en tema oscuro sin errores', (
    tester,
  ) async {
    await _abrirCatalogo(
      tester,
      tamano: const Size(360, 800),
      modo: ThemeMode.dark,
    );

    expect(find.text('Snacks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el carrito muestra el total y la confirmacion en barra fija', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(MemoryOrdersRepository()),
        uidActivoProvider.overrideWithValue('uid-1'),
        staffPermissionProvider.overrideWith((ref) async => false),
        orderClockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        paymentGatewayProvider.overrideWithValue(_PasarelaFalsa()),
        paymentConfiguredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(cartControllerProvider.notifier)
        .addProduct(
          product: Product(id: 'cafe', name: 'Café', priceCents: 550),
          quantity: 2,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FixedBottomBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FixedBottomBar),
        matching: find.text('Total'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(FixedBottomBar),
        matching: find.text('Confirmar pedido'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el carrito vacio no muestra barra de confirmacion', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(MemoryOrdersRepository()),
        uidActivoProvider.overrideWithValue('uid-1'),
        staffPermissionProvider.overrideWith((ref) async => false),
        orderClockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        paymentGatewayProvider.overrideWithValue(_PasarelaFalsa()),
        paymentConfiguredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FixedBottomBar), findsNothing);
    expect(find.text('Tu carrito está vacío.'), findsOneWidget);
  });
}

class _PasarelaFalsa implements PaymentGateway {
  @override
  Future<String> createPaymentIntent(String orderId) async => 'secreto';

  @override
  Future<void> presentPaymentSheet(String clientSecret) async {}
}
