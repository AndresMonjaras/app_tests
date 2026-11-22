import { error as logError } from 'firebase-functions/logger';

import { customerOrderView } from './orders/order_status_rules.mjs';
import { restoreRejectedTicket } from './orders/order_projection.mjs';
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

// Comprueba que el cobro de Stripe corresponde al pedido, al importe y al dueño guardados.
function matchesOrderIntent(order, intent) {
  return (
    !!order &&
    intent?.amount_received === order.totalCents &&
    intent?.currency === 'mxn' &&
    intent?.metadata?.uid === order.ownerUid
  );
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

    let intent;
    try {
      intent = await stripe.paymentIntents.create(
        {
          amount: order.totalCents,
          currency: 'mxn',
          automatic_payment_methods: { enabled: true },
          metadata: { orderId, uid },
        },
        { idempotencyKey: 'order-' + orderId },
      );
    } catch (error) {
      const stripeErrorType = error?.type;
      if (
        stripeErrorType === 'StripeAuthenticationError' ||
        stripeErrorType === 'StripePermissionError'
      ) {
        logError('Stripe rechazó las credenciales de createPaymentIntent.', {
          stripeErrorType,
        });
        throw new AppError(
          'failed-precondition',
          'No se pudo completar la operación. Inténtalo de nuevo.',
        );
      }
      throw error;
    }
    if (!intent.client_secret) {
      throw new AppError('internal', 'Stripe no devolvió el pago solicitado.');
    }
    if (intent.livemode !== false) {
      throw new AppError('internal', 'Stripe no devolvió un pago de prueba.');
    }

    await database.ref('payments/' + orderId).transaction((current) => {
      if (current?.status === 'succeeded') return undefined;
      return { paymentIntentId: intent.id, status: 'requires_payment' };
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

    if (event.livemode !== false) {
      response.status(400).send('Solo se aceptan eventos de prueba.');
      return;
    }

    const ruleByType = {
      'payment_intent.succeeded': { outcome: 'succeeded' },
      'payment_intent.payment_failed': {
        outcome: 'failed',
        fallbackReason: 'El pago fue rechazado.',
      },
      'payment_intent.canceled': {
        outcome: 'failed',
        fallbackReason: 'El pago fue cancelado.',
      },
    };
    const rule = ruleByType[event.type];
    if (!rule) {
      response.status(200).send('Evento ignorado.');
      return;
    }
    const outcome = rule.outcome;

    const intent = event.data?.object;
    if (intent?.metadata?.type === 'membership') {
      if (event.type !== 'payment_intent.succeeded') {
        response.status(200).send('Evento de membresía ignorado.');
        return;
      }
      try {
        const { activateMembershipFromPayment } = await import('./memberships/membership_handlers.mjs');
        const activated = await activateMembershipFromPayment(database, intent);
        response.status(200).send(activated ? 'OK' : 'El cobro no coincide con la membresía.');
      } catch (_) {
        response.status(500).send('No se pudo confirmar la membresía.');
      }
      return;
    }
    const orderId = intent?.metadata?.orderId;
    if (typeof orderId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(orderId)) {
      response.status(200).send('Evento sin pedido asociado.');
      return;
    }

    const failureReason =
      outcome === 'failed'
        ? intent.last_payment_error?.message || rule.fallbackReason
        : undefined;

    // El cobro solo cuenta si coincide con el pedido guardado en el servidor.
    let intentMismatch = false;
    const orderResult = await database
      .ref('orders/' + orderId)
      .transaction((current) => {
        intentMismatch = false;
        // En frío, RTDB empieza con null y necesita consultar al servidor.
        if (current == null) return null;
        if (outcome === 'succeeded' && !matchesOrderIntent(current, intent)) {
          intentMismatch = true;
          return undefined;
        }
        const updated = transitionOrderForPayment(current, outcome, failureReason);
        if (!updated) return undefined;
        // El pedido puede rechazarse antes de que terminemos de actualizar payments.
        if (outcome === 'succeeded') updated.paidPaymentIntentId = intent.id;
        return updated;
      });

    if (intentMismatch) {
      console.error('El cobro no coincide con el pedido.', orderId, intent.id);
      response.status(200).send('El cobro no coincide con el pedido.');
      return;
    }

    const updatedOrder = orderResult.snapshot.val();
    if (orderResult.committed && updatedOrder) {
      const updates = {};
      if (typeof updatedOrder?.ownerUid === 'string') {
        updates[
          'ordersByUser/' + updatedOrder.ownerUid + '/' + orderId
        ] = customerOrderView(updatedOrder);
      }
      if (updatedOrder?.status === 'paid') {
        updates['staffQueue/' + orderId] = { orderId };
      }
      if (Object.keys(updates).length > 0) {
        await database.ref().update(updates);
        if (updatedOrder.status === 'paid') await restoreRejectedTicket(database, orderId);
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
