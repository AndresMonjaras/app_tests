import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/app_theme.dart';
import 'package:lincefood_app/core/preferences/app_preferences_controller.dart';
import 'package:lincefood_app/features/admin/presentation/admin_catalog_providers.dart'
    show adminAccessProvider;
import 'package:lincefood_app/features/auth/presentation/auth_controller.dart'
    show authUserProvider;
import 'package:lincefood_app/features/biometrics/biometric_protection.dart'
    show biometricAvailabilityProvider;
import 'package:lincefood_app/features/cart/presentation/cart_controller.dart';
import 'package:lincefood_app/features/cart/presentation/cart_screen.dart';
import 'package:lincefood_app/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_providers.dart';
import 'package:lincefood_app/features/catalog/presentation/catalog_screen.dart';
import 'package:lincefood_app/features/location/presentation/location_providers.dart'
    show cafeteriaLocationProvider;
import 'package:lincefood_app/features/navigation/app_navigation_shell.dart';
import 'package:lincefood_app/features/orders/data/memory_orders_repository.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart'
    show
        orderClockProvider,
        ordersRepositoryProvider,
        staffPermissionProvider,
        uidActivoProvider;
import 'package:lincefood_app/features/payments/domain/payment_gateway.dart';
import 'package:lincefood_app/features/payments/presentation/payment_providers.dart';
import 'package:lincefood_app/features/profile/data/firebase_profile_repository.dart';
import 'package:lincefood_app/shared/widgets/fixed_bottom_bar.dart';

// Productos de cuatro categorías para probar la cuadrícula.
final _productos = [
  Product(id: 'cafe', name: 'Café', priceCents: 550, categoryId: 'drinks'),
  Product(id: 'flan', name: 'Flan', priceCents: 900, categoryId: 'breakfast'),
  Product(id: 'papas', name: 'Papas', priceCents: 700, categoryId: ''),
  Product(id: 'sopa', name: 'Sopa', priceCents: 1200, categoryId: 'lunch'),
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

    // El orden usa ids de Firebase; las etiquetas visibles están localizadas.
    final otros = tester.getTopLeft(find.text('Otros'));
    final bebidas = tester.getTopLeft(find.text('Bebidas'));
    final comidas = tester.getTopLeft(find.text('Comidas'));
    final desayunos = tester.getTopLeft(find.text('Desayunos'));

    expect(otros.dy, desayunos.dy);
    expect(bebidas.dy, comidas.dy);
    expect(bebidas.dy, greaterThan(otros.dy));
    expect(find.text('breakfast'), findsNothing);
    expect(find.text('lunch'), findsNothing);
    expect(find.text('drinks'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en 1280 px la cuadricula de categorias usa cuatro columnas', (
    tester,
  ) async {
    await _abrirCatalogo(tester, tamano: const Size(1280, 800));

    final y = tester.getTopLeft(find.text('Otros')).dy;
    for (final etiqueta in ['Desayunos', 'Bebidas', 'Comidas']) {
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

  testWidgets('el encabezado de categoria usa la etiqueta en español', (
    tester,
  ) async {
    await _abrirCatalogo(tester, tamano: const Size(360, 800));

    await tester.tap(find.text('Desayunos'));
    await tester.pumpAndSettle();

    expect(find.text('breakfast'), findsNothing);
    expect(find.text('Desayunos'), findsWidgets);
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

    expect(find.text('Desayunos'), findsOneWidget);
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
        matching: find.text(r'Pagar $11.00 MXN'),
      ),
      findsOneWidget,
    );
    expect(find.text('\$5.50 MXN c/u'), findsOneWidget);
    expect(find.text('Subtotal \$11.00 MXN'), findsOneWidget);
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

  testWidgets('el shell usa riel ancho y barra inferior en móvil', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authUserProvider.overrideWith((ref) => Stream.value(_TestUser())),
        appPreferencesProvider.overrideWith(_TestPreferencesController.new),
        biometricAvailabilityProvider.overrideWith((ref) async => false),
        adminAccessProvider.overrideWith((ref) async => false),
        customerProfileProvider.overrideWith((ref) => Stream.value(null)),
        profileSyncProvider.overrideWith((ref) async => false),
        avatarEligibilityProvider.overrideWith((ref) async => false),
        catalogRepositoryProvider.overrideWithValue(
          InMemoryCatalogRepository(_productos),
        ),
        cafeteriaLocationProvider.overrideWith((ref) => Stream.value(null)),
        uidActivoProvider.overrideWithValue('test-uid'),
        staffPermissionProvider.overrideWith((ref) async => false),
        orderClockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ordersRepositoryProvider.overrideWithValue(MemoryOrdersRepository()),
      ],
    );
    addTearDown(container.dispose);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppNavigationShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 800);
    await tester.pump();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestPreferencesController extends AppPreferencesController {
  @override
  Future<AppPreferences> build() async =>
      const AppPreferences(onboardingComplete: true);
}

class _TestUser implements User {
  @override
  String? get displayName => 'Estudiante';

  @override
  String? get email => 'estudiante@example.test';

  @override
  bool get emailVerified => true;

  @override
  String? get photoURL => null;

  @override
  List<UserInfo> get providerData => const <UserInfo>[];

  @override
  String get uid => 'test-uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PasarelaFalsa implements PaymentGateway {
  @override
  Future<String> createPaymentIntent(String orderId) async => 'secreto';

  @override
  Future<void> presentPaymentSheet(String clientSecret) async {}
}
