enum PaymentStatus { inactivo, procesando, pagado, error }

class PaymentState {
  const PaymentState({required this.status, this.message});

  const PaymentState.inactive()
    : status = PaymentStatus.inactivo,
      message = null;

  const PaymentState.processing()
    : status = PaymentStatus.procesando,
      message = null;

  const PaymentState.paid() : status = PaymentStatus.pagado, message = null;

  const PaymentState.error(this.message) : status = PaymentStatus.error;

  final PaymentStatus status;
  final String? message;
}
