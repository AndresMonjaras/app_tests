import { getOrderRefundUpdates } from './order_refund.mjs';
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
      // null también puede ser la caché vacía del Admin SDK: se devuelve tal cual
      // para que la transacción reintente con el valor real del servidor.
      if (order === null) return null;
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
    if (result.snapshot.val() == null) {
      throw new AppError('not-found', 'No se encontró el pedido.');
    }

    const cancelled = result.snapshot.val();
    const at = cancelled.cancelledAt;
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

    const refund = await getOrderRefundUpdates({
      database, stripe, orderId, paidIntentId: cancelled.paidPaymentIntentId,
    });
    const { refundStatus } = refund;
    await database.ref().update({ ...updates, ...refund.updates });

    if (refundStatus === 'pending') {
      throw new AppError(
        'internal',
        'El pedido se canceló, pero el reembolso quedó pendiente. La cafetería lo revisará.',
      );
    }

    return { orderId, status: 'cancelled', refundStatus };
  };
}
