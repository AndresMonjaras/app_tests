import { AppError } from '../app_error.mjs';
import {
  cancellableStatuses,
  customerOrderView,
  normalizeStoredStatus,
  requireOrderId,
  requireOrderObject,
  requireUid,
} from './order_status_rules.mjs';

// Cancela un pedido pagado que todavía no ha entrado a cocina y solicita el
// reembolso en Stripe. Si el reembolso falla, el pedido queda cancelado y el
// reembolso se marca como pendiente para revisarlo manualmente.
export function createCancelOrderHandler({ database, stripe, now = Date.now }) {
  return async (request) => {
    const uid = requireUid(request);
    const orderId = requireOrderId(request.data?.orderId);

    let previousStatus;
    let rejection;
    const result = await database.ref('orders/' + orderId).transaction((order) => {
      try {
        requireOrderObject(order);
        if (order.ownerUid !== uid) {
          throw new AppError('permission-denied', 'No puedes cancelar este pedido.');
        }
        previousStatus = normalizeStoredStatus(order.status);
        if (!cancellableStatuses.has(previousStatus)) {
          throw new AppError(
            'failed-precondition',
            'El pedido ya está en cocina y no se puede cancelar.',
          );
        }
        rejection = undefined;
        return {
          ...order,
          status: 'cancelled',
          isCancelled: true,
          cancelledAt: now(),
          cancelledBy: uid,
        };
      } catch (error) {
        rejection = error;
        return undefined;
      }
    });

    if (!result.committed) {
      throw rejection ?? new AppError('failed-precondition', 'No se pudo cancelar el pedido.');
    }

    const cancelled = result.snapshot.val();
    const at = cancelled.cancelledAt;
    const paymentSnapshot = await database.ref('payments/' + orderId).get();
    const payment = paymentSnapshot.val();

    const eventRef = database.ref('orderEvents/' + orderId).push();
    const updates = {
      ['orderEvents/' + orderId + '/' + eventRef.key]: {
        type: 'order_cancelled',
        from: previousStatus,
        to: 'cancelled',
        actorUid: uid,
        actorRole: 'customer',
        at,
      },
      ['ordersByUser/' + uid + '/' + orderId]: customerOrderView(cancelled),
      ['staffQueue/' + orderId]: null,
    };

    let refundStatus = null;
    if (payment?.status === 'succeeded' && typeof payment.paymentIntentId === 'string') {
      refundStatus = 'requested';
      try {
        await stripe.refunds.create(
          { payment_intent: payment.paymentIntentId },
          { idempotencyKey: 'refund-' + orderId },
        );
      } catch {
        refundStatus = 'pending';
      }
      updates['payments/' + orderId + '/refundStatus'] = refundStatus;
    }

    await database.ref().update(updates);

    if (refundStatus === 'pending') {
      throw new AppError(
        'internal',
        'El pedido se canceló, pero el reembolso quedó pendiente. La cafetería lo revisará.',
      );
    }

    return { orderId, status: 'cancelled', refundStatus };
  };
}
