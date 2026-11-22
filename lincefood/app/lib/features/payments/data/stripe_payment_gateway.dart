import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../domain/payment_gateway.dart';

class StripePaymentGateway implements PaymentGateway {
  StripePaymentGateway({
    required String publishableKey,
    FirebaseFunctions Function()? functionsFactory,
  }) : _publishableKey = publishableKey.trim(),
       _functionsFactory =
           functionsFactory ??
           (() => FirebaseFunctions.instanceFor(region: 'us-central1'));

  final String _publishableKey;
  final FirebaseFunctions Function() _functionsFactory;
  bool _stripeInitialized = false;

  Future<void> _ensureConfigured() async {
    // La app solo trabaja con claves de prueba.
    if (!_publishableKey.startsWith('pk_test_')) {
      throw const PaymentConfigurationException();
    }
    if (_stripeInitialized) return;

    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
    _stripeInitialized = true;
  }

  @override
  Future<String> createPaymentIntent(String orderId) async {
    await _ensureConfigured();

    final result = await _functionsFactory()
        .httpsCallable('createPaymentIntent')
        .call(<String, Object?>{'orderId': orderId});
    final data = result.data;
    if (data is Map && data['clientSecret'] is String) {
      final clientSecret = (data['clientSecret'] as String).trim();
      if (clientSecret.isNotEmpty) return clientSecret;
    }
    throw StateError('No se pudo iniciar el pago.');
  }

  @override
  Future<void> presentPaymentSheet(String clientSecret) async {
    await _ensureConfigured();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'Lincefood',
        paymentIntentClientSecret: clientSecret,
      ),
    );
    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) {
        throw const PaymentCancelledException();
      }
      rethrow;
    }
  }
}
