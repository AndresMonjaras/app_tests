import { restoreRejectedTicket } from './order_projection.mjs';
import { AppError } from '../app_error.mjs';
import {
  activeStatuses,
  nextStaffStatus,
  normalizeStoredStatus,
  queuedStatuses,
  requireAdmin,
  requireNote,
  requireOrderId,
  requireOrderObject,
  customerOrderView,
  requireStaff,
  stampFieldsByStatus,
} from './order_status_rules.mjs';

const cancellationStatuses = new Set(['cancelled', 'canceled', 'cancelado']);
const paymentOnlyStatuses = new Set(['paid', 'payment_pending']);
const staffTargetStatuses = new Set(Object.values(nextStaffStatus));
const previousStaffStatus = {
  confirmed: 'paid',
  preparing: 'confirmed',
  ready: 'preparing',
};


export function createUpdateOrderStatusHandler({
  database,
  now = Date.now,
}) {
  return async (request) => {
    const actor = requireStaff(request);
    const orderId = requireOrderId(request.data?.orderId);
    const requested = request.data?.status;

    if (typeof requested !== 'string') {
      throw new AppError('invalid-argument', 'El estado del pedido no es válido.');
    }
    const target = requested.trim().toLowerCase();

    if (cancellationStatuses.has(target)) {
      throw new AppError(
        'failed-precondition',
        'Un pedido pagado no se cancela desde la aplicación.',
      );
    }
    if (paymentOnlyStatuses.has(target)) {
      throw new AppError(
        'permission-denied',
        'Solo el servicio de pagos puede marcar un pedido como pagado.',
      );
    }

    const isIncident = target === 'incident';
    let incidentReason;
    if (isIncident) {
      requireAdmin(request);
      incidentReason = requireNote(
        request.data?.reason,
        'Indica el motivo de la incidencia.',
      );
    } else if (!staffTargetStatuses.has(target)) {
      throw new AppError('invalid-argument', 'El estado del pedido no es válido.');
    }

    const at = now();
    let previousStatus;
    let validationError;
    const result = await database.ref('orders/' + orderId).transaction((order) => {
      // null también puede ser la caché vacía del Admin SDK: se devuelve tal cual
      // para que la transacción reintente con el valor real del servidor.
      if (order === null) return null;
      try {
        requireOrderObject(order);
        const currentStatus = normalizeStoredStatus(order.status);
        previousStatus = currentStatus;

        if (isIncident) {
          if (!activeStatuses.has(currentStatus)) {
            throw new AppError(
              'failed-precondition',
              'Solo un pedido pagado y activo puede pasar a incidencia.',
            );
          }
          validationError = undefined;
          return {
            ...order,
            status: 'incident',
            incidentAt: at,
            incidentBy: actor.uid,
          };
        }

        if (nextStaffStatus[currentStatus] !== target) {
          const stamp = stampFieldsByStatus[target];
          if (currentStatus === target && stamp && order[stamp.by] === actor.uid) {
            previousStatus = previousStaffStatus[target];
            validationError = undefined;
            return order;
          }
          throw new AppError(
            'failed-precondition',
            'Ese cambio de estado no está permitido para este pedido.',
          );
        }
        const stamp = stampFieldsByStatus[target];
        validationError = undefined;
        return {
          ...order,
          status: target,
          [stamp.at]: at,
          [stamp.by]: actor.uid,
        };
      } catch (error) {
        validationError = error;
        return undefined;
      }
    });

    if (!result.committed) {
      throw (
        validationError ??
        new AppError('failed-precondition', 'No se pudo actualizar el estado del pedido.')
      );
    }
    if (result.snapshot.val() == null) {
      throw new AppError('not-found', 'No se encontró el pedido.');
    }

    const updatedOrder = result.snapshot.val();
    const eventRef = isIncident
      ? database.ref('orderEvents/' + orderId).push()
      : database.ref('orderEvents/' + orderId + '/status_' + target);
    const event = {
      type: isIncident ? 'incident_reported' : 'status_changed',
      from: previousStatus,
      to: isIncident ? 'incident' : target,
      actorUid: actor.uid,
      actorRole: actor.role,
      at,
    };
    if (isIncident) event.reason = incidentReason;

    const updates = {
      ['orderEvents/' + orderId + '/' + eventRef.key]: event,
      ['ordersByUser/' + updatedOrder.ownerUid + '/' + orderId]: customerOrderView(updatedOrder),
      ['staffQueue/' + orderId]: queuedStatuses.has(updatedOrder.status)
        ? { orderId }
        : null,
    };
    await database.ref().update(updates);
    if (target === 'confirmed') await restoreRejectedTicket(database, orderId);

    return { orderId, order: updatedOrder };
  };
}
