abstract interface class PaymentGateway {
  Future<String> createPaymentIntent(String orderId);

  Future<void> presentPaymentSheet(String clientSecret);
}

class PaymentConfigurationException implements Exception {
  const PaymentConfigurationException();

  @override
  String toString() => 'Pagos no configurados';
}

// El usuario cerró la hoja de pago sin pagar. No es un error del sistema.
class PaymentCancelledException implements Exception {
  const PaymentCancelledException();
}

class PaymentDeclinedException implements Exception {
  const PaymentDeclinedException();
}

class PaymentNetworkException implements Exception {
  const PaymentNetworkException();
}
