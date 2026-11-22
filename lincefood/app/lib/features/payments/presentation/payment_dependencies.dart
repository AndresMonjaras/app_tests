import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/in_memory_payment_gateway.dart';
import '../data/stripe_payment_gateway.dart';
import '../domain/payment_gateway.dart';

const _stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

final paymentConfiguredProvider = Provider<bool>((ref) {
  return _stripePublishableKey.trim().isNotEmpty;
});

final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  if (!ref.watch(paymentConfiguredProvider)) {
    return const InMemoryPaymentGateway();
  }
  return StripePaymentGateway(
    publishableKey: _stripePublishableKey,
    functionsFactory: () =>
        FirebaseFunctions.instanceFor(region: 'us-central1'),
  );
});
