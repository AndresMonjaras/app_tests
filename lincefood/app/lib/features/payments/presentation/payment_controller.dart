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
        state.status == PaymentStatus.pagado) {
      return;
    }
    state = const PaymentState.processing();

    try {
      final gateway = ref.read(paymentGatewayProvider);
      final clientSecret = await gateway.createPaymentIntent(orderId);
      if (!ref.mounted) return;

      await gateway.presentPaymentSheet(clientSecret);
      if (!ref.mounted) return;
      state = const PaymentState.paid();
    } on PaymentConfigurationException {
      if (!ref.mounted) return;
      state = const PaymentState.error('Pagos no configurados');
    } catch (_) {
      if (!ref.mounted) return;
      state = const PaymentState.error(
        'No se pudo procesar el pago. Inténtalo de nuevo.',
      );
    }
  }
}
