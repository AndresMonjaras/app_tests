import '../domain/payment_gateway.dart';

class InMemoryPaymentGateway implements PaymentGateway {
  const InMemoryPaymentGateway({this.simulateSuccessfulPayments = false});

  final bool simulateSuccessfulPayments;

  @override
  Future<String> createPaymentIntent(String orderId) async {
    if (!simulateSuccessfulPayments) {
      throw const PaymentConfigurationException();
    }
    return 'simulated-client-secret';
  }

  @override
  Future<void> presentPaymentSheet(String clientSecret) async {
    if (!simulateSuccessfulPayments) {
      throw const PaymentConfigurationException();
    }
  }
}
