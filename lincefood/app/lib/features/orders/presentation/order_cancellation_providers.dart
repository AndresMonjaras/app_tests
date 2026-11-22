import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/callable_order_cancellation_gateway.dart';

final orderCancellationGatewayProvider = Provider<OrderCancellationGateway>(
  (ref) => CallableOrderCancellationGateway(),
);

/// Pedidos cuya cancelación está en curso, para no enviar la petición dos veces.
class CancellingOrdersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void start(String orderId) => state = {...state, orderId};

  void finish(String orderId) => state = {...state}..remove(orderId);
}

final cancellingOrdersProvider =
    NotifierProvider<CancellingOrdersNotifier, Set<String>>(
      CancellingOrdersNotifier.new,
    );
