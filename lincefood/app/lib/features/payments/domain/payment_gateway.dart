abstract interface class PaymentGateway {
  Future<String> createPaymentIntent(String orderId);

  Future<void> presentPaymentSheet(String clientSecret);
}

class PaymentConfigurationException implements Exception {
  const PaymentConfigurationException();

  @override
  String toString() => 'Pagos no configurados';
}
