enum OrderStatus {
  paymentPending,
  paid,
  confirmed,
  preparing,
  ready,
  delivered,
  incident,
}

extension OrderStatusCode on OrderStatus {
  String get code => switch (this) {
    OrderStatus.paymentPending => 'payment_pending',
    OrderStatus.paid => 'paid',
    OrderStatus.confirmed => 'confirmed',
    OrderStatus.preparing => 'preparing',
    OrderStatus.ready => 'ready',
    OrderStatus.delivered => 'delivered',
    OrderStatus.incident => 'incident',
  };

  String get label => switch (this) {
    OrderStatus.paymentPending => 'Pago pendiente',
    OrderStatus.paid => 'Pagado',
    OrderStatus.confirmed => 'Confirmado',
    OrderStatus.preparing => 'En cocina',
    OrderStatus.ready => 'Listo para recoger',
    OrderStatus.delivered => 'Entregado',
    OrderStatus.incident => 'Revisar pedido',
  };
}

bool canCustomerCancel(OrderStatus status) {
  return status == OrderStatus.paymentPending;
}

OrderStatus orderStatusFromCode(Object? value) {
  final code = value?.toString().trim().toLowerCase();
  for (final status in OrderStatus.values) {
    if (status.code == code) return status;
  }

  return switch (code) {
    'pendiente' => OrderStatus.paymentPending,
    'pagado' => OrderStatus.paid,
    'confirmado' => OrderStatus.confirmed,
    'preparando' ||
    'en preparación' ||
    'en preparacion' => OrderStatus.preparing,
    'listo' || 'listo para recoger' => OrderStatus.ready,
    'entregado' => OrderStatus.delivered,
    'incidente' => OrderStatus.incident,
    _ => OrderStatus.paymentPending,
  };
}
