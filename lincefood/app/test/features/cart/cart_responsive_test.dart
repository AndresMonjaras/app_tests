import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/app/app_theme.dart';
import 'package:lincefood_app/features/cart/presentation/cart_controller.dart';
import 'package:lincefood_app/features/cart/presentation/cart_screen.dart';
import 'package:lincefood_app/features/catalog/domain/product.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart';
import 'package:lincefood_app/features/payments/presentation/payment_providers.dart';
import 'package:lincefood_app/shared/widgets/fixed_bottom_bar.dart';

void main() {
  for (final size in const [
    Size(360, 800),
    Size(768, 1024),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    testWidgets('Distribución del carrito a ${size.width} × ${size.height}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          uidActivoProvider.overrideWithValue('cliente'),
          paymentConfiguredProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      final cart = container.read(cartControllerProvider.notifier);
      cart.addProduct(
        product: Product(id: 'cafe', name: 'Café', priceCents: 550),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light, home: const CartScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final product = tester.getRect(find.text('Café'));
      final pickup = tester.getRect(find.text('Modalidad de recogida'));
      final pay = find.widgetWithText(FilledButton, r'Pagar $5.50 MXN');
      if (size.width >= 1024) {
        expect(find.byType(FixedBottomBar), findsNothing);
        expect(product.right, lessThan(pickup.left));
        final panel = find.ancestor(of: pay, matching: find.byType(ListView));
        expect(tester.getSize(panel).width, 380);
        expect(tester.getRect(panel).right, (size.width + 1280) / 2 - 24);
        expect(
          find.descendant(of: panel, matching: find.text('Subtotal')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: panel,
            matching: find.text('Modalidad de recogida'),
          ),
          findsOneWidget,
        );
      } else {
        expect(product.bottom, lessThan(pickup.top));
        expect(
          find.descendant(of: find.byType(FixedBottomBar), matching: pay),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      cart.clear();
      await tester.pumpAndSettle();
      expect(find.text('Tu carrito está vacío.'), findsOneWidget);
      expect(find.byType(FixedBottomBar), findsNothing);
      expect(pay, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
