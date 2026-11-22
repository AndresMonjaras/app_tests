import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/payments/data/stripe_payment_gateway.dart';

void main() {
  test('sin clave publicable devuelve Pagos no configurados', () async {
    var functionsRequested = false;
    final gateway = StripePaymentGateway(
      publishableKey: '',
      functionsFactory: () {
        functionsRequested = true;
        throw StateError('No debe inicializar Functions.');
      },
    );

    await expectLater(
      gateway.createPaymentIntent('order-1'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'mensaje',
          'Pagos no configurados',
        ),
      ),
    );
    expect(functionsRequested, isFalse);
  });

  test('una clave que no es de prueba no inicia el pago', () async {
    var functionsRequested = false;
    final gateway = StripePaymentGateway(
      publishableKey: 'clave-no-de-prueba',
      functionsFactory: () {
        functionsRequested = true;
        throw StateError('No debe inicializar Functions.');
      },
    );

    await expectLater(
      gateway.createPaymentIntent('order-1'),
      throwsA(isA<Exception>()),
    );
    expect(functionsRequested, isFalse);
  });
}
