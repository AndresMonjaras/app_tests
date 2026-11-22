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

    try {
      final result = await _functionsFactory()
          .httpsCallable('createPaymentIntent')
          .call(<String, Object?>{'orderId': orderId});
      final data = result.data;
      if (data is Map && data['clientSecret'] is String) {
        final clientSecret = (data['clientSecret'] as String).trim();
        if (clientSecret.isNotEmpty) return clientSecret;
      }
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed') {
        throw const PaymentNetworkException();
      }
      rethrow;
    }
    throw StateError('No se pudo iniciar el pago.');
  }

  @override
  Future<void> presentPaymentSheet(String clientSecret) async {
    await _ensureConfigured();
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Lincefood',
          paymentIntentClientSecret: clientSecret,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) {
        throw const PaymentCancelledException();
      }
      if (error.error.code == FailureCode.Timeout ||
          error.error.type == 'api_connection_error' ||
          error.error.stripeErrorCode == 'connection_error') {
        throw const PaymentNetworkException();
      }
      if (error.error.declineCode != null ||
          error.error.stripeErrorCode == 'card_declined' ||
          error.error.type == 'card_error') {
        throw const PaymentDeclinedException();
      }
      rethrow;
    }
  }
}
