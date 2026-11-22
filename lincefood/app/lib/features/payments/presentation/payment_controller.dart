import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/payment_gateway.dart';
import '../domain/payment_state.dart';
import 'payment_dependencies.dart';

class PaymentController extends Notifier<PaymentState> {
  @override
  PaymentState build() => const PaymentState.inactive();

  void reset() => state = const PaymentState.inactive();

  Future<void> pay({required String orderId}) async {
    if (state.status == PaymentStatus.procesando ||
        state.status == PaymentStatus.esperandoConfirmacion) {
      return;
    }
    state = const PaymentState.processing();

    try {
      final gateway = ref.read(paymentGatewayProvider);
      final clientSecret = await gateway.createPaymentIntent(orderId);
      if (!ref.mounted) return;

      await gateway.presentPaymentSheet(clientSecret);
      if (!ref.mounted) return;
      // El retorno local de la hoja no prueba el pago: el webhook lo confirma.
      state = const PaymentState.awaitingConfirmation();
    } on PaymentConfigurationException {
      if (!ref.mounted) return;
      state = const PaymentState.error('Pagos no configurados');
    } on PaymentCancelledException {
      if (!ref.mounted) return;
      state = const PaymentState.inactive();
    } on PaymentDeclinedException {
      if (!ref.mounted) return;
      state = const PaymentState.error(
        'Pago rechazado. Tu pedido sigue pendiente. Intenta con otro método.',
      );
    } on PaymentNetworkException {
      if (!ref.mounted) return;
      state = const PaymentState.error(
        'Sin conexión para procesar el pago. Inténtalo de nuevo.',
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = const PaymentState.error(
        'No se pudo procesar el pago. Inténtalo de nuevo.',
      );
    }
  }
}
