import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/payments/domain/payment_gateway.dart';
import 'package:lincefood_app/features/payments/domain/payment_state.dart';
import 'package:lincefood_app/features/payments/presentation/payment_providers.dart';

class _FakePaymentGateway implements PaymentGateway {
  _FakePaymentGateway({this.createIntent, this.createError, this.presentError});

  final Future<String> Function(String orderId)? createIntent;
  final Object? createError;
  final Object? presentError;

  @override
  Future<String> createPaymentIntent(String orderId) {
    if (createError != null) return Future<String>.error(createError!);
    return createIntent?.call(orderId) ??
        Future<String>.value('simulated-client-secret');
  }

  @override
  Future<void> presentPaymentSheet(String clientSecret) {
    if (presentError != null) return Future<void>.error(presentError!);
    return Future<void>.value();
  }
}

void main() {
  test(
    'transiciona de inactivo a procesando y luego a esperar confirmación',
    () async {
      final intentCompleter = Completer<String>();
      final container = ProviderContainer(
        overrides: [
          paymentGatewayProvider.overrideWithValue(
            _FakePaymentGateway(createIntent: (_) => intentCompleter.future),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(paymentControllerProvider.notifier);
      expect(
        container.read(paymentControllerProvider).status,
        PaymentStatus.inactivo,
      );

      final payment = controller.pay(orderId: 'order-1');
      expect(
        container.read(paymentControllerProvider).status,
        PaymentStatus.procesando,
      );

      intentCompleter.complete('simulated-client-secret');
      await payment;
      expect(
        container.read(paymentControllerProvider).status,
        PaymentStatus.esperandoConfirmacion,
      );
    },
  );

  test(
    'una hoja de pago cerrada sin pagar vuelve a inactivo sin error',
    () async {
      final container = ProviderContainer(
        overrides: [
          paymentGatewayProvider.overrideWithValue(
            _FakePaymentGateway(
              presentError: const PaymentCancelledException(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(paymentControllerProvider.notifier)
          .pay(orderId: 'order-1');

      final state = container.read(paymentControllerProvider);
      expect(state.status, PaymentStatus.inactivo);
      expect(state.message, isNull);
    },
  );

  test('muestra un estado de error si falla el gateway', () async {
    final container = ProviderContainer(
      overrides: [
        paymentGatewayProvider.overrideWithValue(
          _FakePaymentGateway(createError: StateError('error de prueba')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(paymentControllerProvider.notifier)
        .pay(orderId: 'order-1');

    final state = container.read(paymentControllerProvider);
    expect(state.status, PaymentStatus.error);
    expect(state.message, 'No se pudo procesar el pago. Inténtalo de nuevo.');
  });

  test('permite iniciar un pago nuevo después de completar uno', () async {
    final container = ProviderContainer(
      overrides: [
        paymentGatewayProvider.overrideWithValue(_FakePaymentGateway()),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(paymentControllerProvider.notifier);

    await controller.pay(orderId: 'order-1');
    expect(
      container.read(paymentControllerProvider).status,
      PaymentStatus.esperandoConfirmacion,
    );

    controller.reset();
    await controller.pay(orderId: 'order-2');
    expect(
      container.read(paymentControllerProvider).status,
      PaymentStatus.esperandoConfirmacion,
    );
  });

  test('muestra error si falla la presentación de la hoja de pago', () async {
    final container = ProviderContainer(
      overrides: [
        paymentGatewayProvider.overrideWithValue(
          _FakePaymentGateway(presentError: StateError('error de prueba')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(paymentControllerProvider.notifier)
        .pay(orderId: 'order-1');

    final state = container.read(paymentControllerProvider);
    expect(state.status, PaymentStatus.error);
    expect(state.message, 'No se pudo procesar el pago. Inténtalo de nuevo.');
  });
}
