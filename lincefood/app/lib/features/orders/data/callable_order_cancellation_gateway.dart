import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/errors/domain_exception.dart';

/// Pide al servidor cancelar un pedido propio antes de que entre a cocina.
abstract interface class OrderCancellationGateway {
  Future<void> cancel(String orderId);
}

class CallableOrderCancellationGateway implements OrderCancellationGateway {
  @override
  Future<void> cancel(String orderId) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('cancelOrder')
          .call({'orderId': orderId});
    } on FirebaseFunctionsException catch (error) {
      throw DomainException(error.message ?? 'No se pudo cancelar el pedido.');
    }
  }
}
