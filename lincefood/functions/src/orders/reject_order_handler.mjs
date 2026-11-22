import { AppError } from '../app_error.mjs';
import { getOrderRefundUpdates } from './order_refund.mjs';
import {
  customerOrderView, normalizeStoredStatus, requireOrderId,
  requireOrderObject, requireStaff,
} from './order_status_rules.mjs';

const noticeDurationMs = 10 * 60 * 1000;
const characters = new Intl.Segmenter('es', { granularity: 'grapheme' });

function rejectionReason(value) {
  const reason = typeof value === 'string' ? value.trim() : '';
  let length = 0;
  for (const _ of characters.segment(reason)) {
    if (++length > 200) break;
  }
  if (length < 5 || length > 200) {
    throw new AppError('invalid-argument', 'Escribe una nota de 5 a 200 caracteres.');
  }
  return reason;
}

export function createRejectOrderHandler({ database, stripe, now = Date.now }) {
  return async (request) => {
    const actor = requireStaff(request);
    const orderId = requireOrderId(request.data?.orderId);
    const reason = rejectionReason(request.data?.reason);
    const at = now();
    const orderPath = 'orders/' + orderId;
    let validationError;
    const result = await database.ref(orderPath).transaction((order) => {
      if (order === null) return null; // La caché fría todavía no conoce el pedido.
      try {
        requireOrderObject(order);
        const status = normalizeStoredStatus(order.status ?? order.estado);
        // La misma solicitud puede reanudar un rechazo interrumpido tras el commit.
        if (
          status === 'rejected' && order.rejectionPendingFrom &&
          order.rejectedBy === actor.uid && order.rejectionReason === reason
        ) {
          return order;
        }
        if (status !== 'paid' && status !== 'confirmed') {
          throw new AppError('failed-precondition', 'Solo puedes rechazar un pedido pagado o confirmado.');
        }
        return {
          ...order,
          status: 'rejected',
          rejectionReason: reason,
          rejectedAt: at,
          rejectedBy: actor.uid,
          rejectionPendingFrom: status,
        };
      } catch (error) {
        validationError = error;
        return undefined;
      }
    });

    if (!result.committed) {
      throw validationError ?? new AppError('failed-precondition', 'No se pudo rechazar el pedido.');
    }
    const order = result.snapshot.val();
    if (!order) throw new AppError('not-found', 'No se encontró el pedido.');

    const ticket = customerOrderView(order);
    await database.ref().update({
      ['ordersByUser/' + order.ownerUid + '/' + orderId]: ticket,
      ['staffQueue/' + orderId]: null,
      ['rejectionNotices/' + order.ownerUid + '/' + orderId]: {
        rejectionReason: reason,
        rejectedAt: order.rejectedAt,
        expiresAt: order.rejectedAt + noticeDurationMs,
      },
      ['orderEvents/' + orderId + '/rejected']: {
        type: 'order_rejected',
        from: order.rejectionPendingFrom,
        to: 'rejected',
        actorUid: actor.uid,
        actorRole: actor.role,
        at: order.rejectedAt,
        reason,
      },
    });

    const refund = await getOrderRefundUpdates({
      database, stripe, orderId, paidIntentId: order.paidPaymentIntentId, expectPayment: true,
    });
    if (refund.refundStatus === 'pending') {
      throw new AppError(
        'internal',
        'El pedido se rechazó, pero el reembolso quedó pendiente. La cafetería lo revisará.',
      );
    }
    await database.ref().update({
      ...refund.updates,
      [orderPath + '/rejectionPendingFrom']: null,
    });
    return { orderId, order: ticket, status: 'rejected', refundStatus: refund.refundStatus };
  };
}
