import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/payments/domain/payment_gateway.dart';
import 'package:lincefood_app/features/payments/presentation/payment_providers.dart';
import 'package:lincefood_app/features/payments/presentation/payment_screen.dart';
import 'package:lincefood_app/features/orders/presentation/orders_providers.dart'
    show uidActivoProvider, staffPermissionProvider;

class _PendingPaymentGateway implements PaymentGateway {
  final Completer<String> _intent = Completer<String>();

  void completeIntent() => _intent.complete('simulated-client-secret');

  @override
  Future<String> createPaymentIntent(String orderId) => _intent.future;

  @override
  Future<void> presentPaymentSheet(String clientSecret) async {}
}

void main() {
  testWidgets('muestra error de configuración y no inicia el gateway', (
    tester,
  ) async {
    final gateway = _PendingPaymentGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentGatewayProvider.overrideWithValue(gateway),
          paymentConfiguredProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: PaymentScreen(orderId: 'order-1', totalCents: 1250),
        ),
      ),
    );

    expect(find.text('Pagos no configurados'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('deshabilita el botón mientras procesa el pago', (tester) async {
    final gateway = _PendingPaymentGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentGatewayProvider.overrideWithValue(gateway),
          paymentConfiguredProvider.overrideWithValue(true),
          uidActivoProvider.overrideWithValue('uid-1'),
          staffPermissionProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: PaymentScreen(orderId: 'order-1', totalCents: 1250),
        ),
      ),
    );

    final button = find.byType(ElevatedButton);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    expect(find.text(r'$12.50 MXN'), findsOneWidget);

    await tester.tap(button);
    await tester.pump();

    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Pagar ahora'), findsOneWidget);

    gateway.completeIntent();
    await tester.pumpAndSettle();
    expect(find.text('Mi ticket'), findsOneWidget);
  });
}
