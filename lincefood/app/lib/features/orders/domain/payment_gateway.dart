import 'order_record.dart';

class PaymentResult {
  const PaymentResult({required this.approved, this.message});

  final bool approved;
  final String? message;
}

abstract interface class PaymentGateway {
  Future<PaymentResult> pay(OrderRecord order);
}
