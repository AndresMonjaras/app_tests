const paymentPendingStatuses = new Set([
  'payment_pending',
  'pendiente_pago',
  'pendiente',
]);

export function transitionOrderForPayment(order, outcome, failureReason) {
  if (!order) return null;

  const status = String(order.status ?? '').trim().toLowerCase();

  if (outcome === 'succeeded') {
    if (!paymentPendingStatuses.has(status)) return null;
    const updated = { ...order, status: 'paid' };
    delete updated.paymentFailureReason;
    return updated;
  }

  if (outcome === 'failed') {
    if (!paymentPendingStatuses.has(status)) return null;
    if ((order.paymentFailureReason || undefined) === failureReason) {
      return null;
    }
    const updated = { ...order, status: 'pendiente_pago' };
    if (failureReason) updated.paymentFailureReason = failureReason;
    return updated;
  }

  return null;
}

export function transitionPaymentRecord(
  payment,
  outcome,
  { paymentIntentId, failureReason } = {},
) {
  if (payment?.status === 'succeeded') return null;

  if (outcome === 'succeeded') {
    const updated = { ...payment, status: 'succeeded' };
    if (paymentIntentId) updated.paymentIntentId = paymentIntentId;
    delete updated.failureReason;
    return updated;
  }

  if (outcome === 'failed') {
    if (
      payment?.status === 'failed' &&
      (!paymentIntentId || payment.paymentIntentId === paymentIntentId) &&
      (payment.failureReason || undefined) === failureReason
    ) {
      return null;
    }
    const updated = { ...payment, status: 'failed' };
    if (paymentIntentId) updated.paymentIntentId = paymentIntentId;
    if (failureReason) updated.failureReason = failureReason;
    return updated;
  }

  return null;
}
