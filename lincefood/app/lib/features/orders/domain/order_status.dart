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

/// El cliente puede cancelar mientras el pedido no haya entrado a cocina.
bool canCustomerCancel(OrderStatus status) {
  return status == OrderStatus.paymentPending ||
      status == OrderStatus.paid ||
      status == OrderStatus.confirmed;
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

extension OrderStatusFlow on OrderStatus {
  /// Siguiente paso que puede aplicar el personal. Null si no hay ninguno.
  /// La entrega no está aquí: solo ocurre al escanear el QR de recogida.
  OrderStatus? get nextStaffStep => switch (this) {
    OrderStatus.paid => OrderStatus.confirmed,
    OrderStatus.confirmed => OrderStatus.preparing,
    OrderStatus.preparing => OrderStatus.ready,
    _ => null,
  };

  /// Solo un pedido pagado y activo puede pasar a incidencia.
  bool get allowsIncident => switch (this) {
    OrderStatus.paid ||
    OrderStatus.confirmed ||
    OrderStatus.preparing ||
    OrderStatus.ready => true,
    _ => false,
  };
}
