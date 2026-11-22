// El pedido solo queda pagado cuando el servidor lo confirma por webhook.
// Tras la hoja de pago únicamente se espera esa confirmación.
enum PaymentStatus { inactivo, procesando, esperandoConfirmacion, error }

class PaymentState {
  const PaymentState({required this.status, this.message});

  const PaymentState.inactive()
    : status = PaymentStatus.inactivo,
      message = null;

  const PaymentState.processing()
    : status = PaymentStatus.procesando,
      message = null;

  const PaymentState.awaitingConfirmation()
    : status = PaymentStatus.esperandoConfirmacion,
      message = null;

  const PaymentState.error(this.message) : status = PaymentStatus.error;

  final PaymentStatus status;
  final String? message;
}
