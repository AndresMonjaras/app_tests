import { AppError } from '../app_error.mjs';
import {
  customerOrderView,
  normalizeStoredStatus,
  requireAdmin,
  requireNote,
  requireOrderId,
  requireOrderObject,
} from './order_status_rules.mjs';

// Solo un administrador cierra una incidencia. El pedido conserva el estado
// incident y queda registrado quién la resolvió y cuándo.
export function createResolveOrderIncidentHandler({ database, now = Date.now }) {
  return async (request) => {
    const actor = requireAdmin(request);
    const orderId = requireOrderId(request.data?.orderId);
    const resolution = requireNote(
      request.data?.resolution,
      'Indica cómo se resolvió la incidencia.',
    );

    const at = now();
    let validationError;
    const result = await database.ref('orders/' + orderId).transaction((order) => {
      try {
        requireOrderObject(order);
        if (normalizeStoredStatus(order.status) !== 'incident') {
          throw new AppError('failed-precondition', 'El pedido no está en incidencia.');
        }
        if (order.incidentResolvedAt) {
          throw new AppError('failed-precondition', 'La incidencia ya está resuelta.');
        }
        validationError = undefined;
        return { ...order, incidentResolvedAt: at, incidentResolvedBy: actor.uid };
      } catch (error) {
        validationError = error;
        return undefined;
      }
    });

    if (!result.committed) {
      throw (
        validationError ??
        new AppError('failed-precondition', 'No se pudo resolver la incidencia.')
      );
    }

    const updatedOrder = result.snapshot.val();
    const eventRef = database.ref('orderEvents/' + orderId).push();
    const updates = {
      ['orderEvents/' + orderId + '/' + eventRef.key]: {
        type: 'incident_resolved',
        from: 'incident',
        to: 'incident',
        actorUid: actor.uid,
        actorRole: actor.role,
        at,
        note: resolution,
      },
      ['ordersByUser/' + updatedOrder.ownerUid + '/' + orderId]: customerOrderView(updatedOrder),
      ['staffQueue/' + orderId]: null,
    };
    await database.ref().update(updates);

    return { orderId, order: updatedOrder };
  };
}
