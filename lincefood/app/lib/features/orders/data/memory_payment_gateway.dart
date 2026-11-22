import '../domain/order_record.dart';
import '../domain/payment_gateway.dart';

class MemoryPaymentGateway implements PaymentGateway {
  MemoryPaymentGateway({this.approvePayments = true});

  final bool approvePayments;
  final List<String> paidOrderIds = [];

  @override
  Future<PaymentResult> pay(OrderRecord order) async {
    if (!approvePayments) {
      return const PaymentResult(
        approved: false,
        message: 'No se completó el pago de prueba.',
      );
    }
    paidOrderIds.add(order.id);
    return const PaymentResult(approved: true);
  }
}
