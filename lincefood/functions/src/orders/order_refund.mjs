// Un reintento tardío que falló no debe degradar un reembolso ya solicitado.
async function markRefundPending(database, path) {
  const result = await database.ref(path + '/refundStatus').transaction((current) =>
    current === 'requested' ? current : 'pending',
  );
  return { refundStatus: result.snapshot.val(), updates: {} };
}

export async function getOrderRefundUpdates({
  database, stripe, orderId, paidIntentId, expectPayment = false,
}) {
  const path = 'payments/' + orderId;
  const payment = (await database.ref(path).get()).val();
  if (payment?.refundStatus === 'requested') {
    return { refundStatus: 'requested', updates: {} };
  }
  const intentId = paidIntentId ?? payment?.paymentIntentId;
  if (typeof intentId !== 'string' || !intentId) {
    if (expectPayment) return markRefundPending(database, path);
    return { refundStatus: null, updates: {} };
  }

  try {
    // El webhook puede ir por detrás de Stripe. Solo se anula un intento cuyo
    // estado se ha podido comprobar; un fallo de consulta queda para revisión.
    const succeeded = payment?.status === 'succeeded' && payment.paymentIntentId === intentId;
    const status = succeeded ? 'succeeded' : (await stripe.paymentIntents.retrieve(intentId)).status;
    if (status !== 'succeeded') {
      if (status !== 'canceled') await stripe.paymentIntents.cancel(intentId);
      return { refundStatus: null, updates: {
        [path + '/status']: 'canceled',
        [path + '/refundStatus']: null,
      } };
    }
    await stripe.refunds.create(
      { payment_intent: intentId },
      { idempotencyKey: 'refund-' + orderId },
    );
    return { refundStatus: 'requested', updates: { [path + '/refundStatus']: 'requested' } };
  } catch {
    return markRefundPending(database, path);
  }
}
