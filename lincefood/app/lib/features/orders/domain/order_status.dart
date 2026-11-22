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
}

bool canCustomerCancel(OrderStatus status) {
  return status == OrderStatus.paymentPending;
}
