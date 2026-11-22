import { AppError } from './app_error.mjs';
import { validateAndPriceOrderLines } from './order_pricing.mjs';
import {
  transitionOrderForPayment,
  transitionPaymentRecord,
} from './payment_transitions.mjs';

function requireUid(request) {
  const uid = request.auth?.uid;
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  return uid;
}

function requireOrderId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new AppError('invalid-argument', 'El pedido no es válido.');
  }
  return value;
}

export function createCreateOrderHandler({ database, serverTimestamp }) {
  return async (request) => {
    const uid = requireUid(request);
    const productSnapshot = await database.ref('products').get();
    const products = productSnapshot.val();
    const { lines, totalCents } = validateAndPriceOrderLines(
      request.data?.lines,
      products,
    );

    const orderId = database.ref('orders').push().key;
    if (typeof orderId !== 'string' || orderId.length === 0) {
      throw new AppError('internal', 'No se pudo crear el pedido.');
    }
    const folio = 'LF-' + orderId.slice(-8).toUpperCase();
    const order = {
      ownerUid: uid,
      folio,
      status: 'pendiente_pago',
      totalCents,
      lines,
      pickupMode:
        request.data?.pickupMode === 'take_away' ? 'take_away' : 'in_store',
      createdAt: serverTimestamp(),
    };
    const updates = {};
    updates['orders/' + orderId] = order;
    updates['ordersByUser/' + uid + '/' + orderId] = order;
    updates['staffQueue/' + orderId] = { orderId };
    await database.ref().update(updates);

    return { orderId, folio };
  };
}

export function createCreatePaymentIntentHandler({ database, stripe }) {
  return async (request) => {
    const uid = requireUid(request);
    const orderId = requireOrderId(request.data?.orderId);
    const orderSnapshot = await database.ref('orders/' + orderId).get();
    const order = orderSnapshot.val();

    if (!order) {
      throw new AppError('not-found', 'No se encontró el pedido.');
    }
    if (order.ownerUid !== uid) {
      throw new AppError('permission-denied', 'No puedes pagar este pedido.');
    }
    if (order.status !== 'pendiente_pago') {
      throw new AppError(
        'failed-precondition',
        'El pedido no está pendiente de pago.',
      );
    }
    if (!Number.isSafeInteger(order.totalCents) || order.totalCents <= 0) {
      throw new AppError(
        'failed-precondition',
        'El total del pedido no permite iniciar un pago.',
      );
    }

    const intent = await stripe.paymentIntents.create(
      {
        amount: order.totalCents,
        currency: 'mxn',
        automatic_payment_methods: { enabled: true },
        metadata: { orderId },
      },
      { idempotencyKey: 'order-' + orderId },
    );
    if (!intent.client_secret) {
      throw new AppError('internal', 'Stripe no devolvió el pago solicitado.');
    }

    await database.ref('payments/' + orderId).set({
      paymentIntentId: intent.id,
      status: 'requires_payment',
    });
    return { clientSecret: intent.client_secret };
  };
}

export function createStripeWebhookHandler({
  database,
  stripe,
  webhookSecret,
}) {
  return async (request, response) => {
    let event;
    try {
      const signature =
        request.get?.('stripe-signature') ??
        request.headers?.['stripe-signature'];
      if (!signature || !request.rawBody) {
        throw new Error('Falta la firma o el cuerpo original.');
      }
      event = stripe.webhooks.constructEvent(
        request.rawBody,
        signature,
        webhookSecret,
      );
    } catch (_) {
      response.status(400).send('Firma de webhook no válida.');
      return;
    }

    const outcomeByType = {
      'payment_intent.succeeded': 'succeeded',
      'payment_intent.payment_failed': 'failed',
    };
    const outcome = outcomeByType[event.type];
    if (!outcome) {
      response.status(200).send('Evento ignorado.');
      return;
    }

    const intent = event.data?.object;
    const orderId = intent?.metadata?.orderId;
    if (typeof orderId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(orderId)) {
      response.status(200).send('Evento sin pedido asociado.');
      return;
    }

    const failureReason =
      outcome === 'failed'
        ? intent.last_payment_error?.message || 'El pago fue rechazado.'
        : undefined;
    const orderResult = await database
      .ref('orders/' + orderId)
      .transaction((current) =>
        transitionOrderForPayment(current, outcome, failureReason) ?? undefined,
      );

    if (orderResult.committed) {
      const updatedOrder = orderResult.snapshot.val();
      const updates = {};
      if (typeof updatedOrder?.ownerUid === 'string') {
        updates[
          'ordersByUser/' + updatedOrder.ownerUid + '/' + orderId
        ] = updatedOrder;
      }
      if (updatedOrder?.status === 'pagado') {
        updates['staffQueue/' + orderId] = { orderId };
      }
      if (Object.keys(updates).length > 0) {
        await database.ref().update(updates);
      }

      await database
        .ref('payments/' + orderId)
        .transaction((current) =>
          transitionPaymentRecord(current, outcome, {
            paymentIntentId: intent.id,
            failureReason,
          }) ?? undefined,
        );
    }

    response.status(200).send('OK');
  };
}
