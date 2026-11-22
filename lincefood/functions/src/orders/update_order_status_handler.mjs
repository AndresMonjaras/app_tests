import { AppError } from '../app_error.mjs';

const orderStatusIndex = {
  payment_pending: 0,
  paid: 1,
  confirmed: 2,
  preparing: 3,
  ready: 4,
  delivered: 5,
  incident: 6,
};

const storedStatusAliases = {
  pendiente: 'payment_pending',
  pendiente_pago: 'payment_pending',
  pagado: 'paid',
  confirmado: 'confirmed',
  preparando: 'preparing',
  'en preparación': 'preparing',
  'en preparacion': 'preparing',
  listo: 'ready',
  'listo para recoger': 'ready',
  entregado: 'delivered',
  incidente: 'incident',
};

const queuedStatuses = new Set(['paid', 'confirmed', 'preparing', 'ready']);
const cancellationStatuses = new Set(['cancelled', 'canceled', 'cancelado']);

function requireOrderId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new AppError('invalid-argument', 'El pedido no es válido.');
  }
  return value;
}

function normalizeStoredStatus(value) {
  const status = String(value ?? '').trim().toLowerCase();
  if (Object.hasOwn(orderStatusIndex, status)) return status;
  return storedStatusAliases[status] ?? 'payment_pending';
}

function requireStaff(request) {
  if (typeof request.auth?.uid !== 'string' || request.auth.uid.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  if (
    request.auth.token?.staff !== true &&
    request.auth.token?.admin !== true
  ) {
    throw new AppError(
      'permission-denied',
      'Solo el personal puede actualizar el estado de un pedido.',
    );
  }
}

export function createUpdateOrderStatusHandler({ database }) {
  return async (request) => {
    requireStaff(request);
    const orderId = requireOrderId(request.data?.orderId);
    const nextStatus = request.data?.status;
    const isCancellation =
      typeof nextStatus === 'string' &&
      cancellationStatuses.has(nextStatus.toLowerCase());

    if (
      typeof nextStatus !== 'string' ||
      (!isCancellation && !Object.hasOwn(orderStatusIndex, nextStatus))
    ) {
      throw new AppError('invalid-argument', 'El estado del pedido no es válido.');
    }

    let validationError;
    const result = await database.ref('orders/' + orderId).transaction((order) => {
      if (!order || typeof order !== 'object' || Array.isArray(order)) {
        validationError = new AppError('not-found', 'No se encontró el pedido.');
        return undefined;
      }
      if (typeof order.ownerUid !== 'string' || order.ownerUid.length === 0) {
        validationError = new AppError(
          'failed-precondition',
          'El pedido no tiene un propietario válido.',
        );
        return undefined;
      }
      if (order.isCancelled === true) {
        validationError = new AppError(
          'failed-precondition',
          'Un pedido cancelado no puede cambiar.',
        );
        return undefined;
      }

      const currentStatus = normalizeStoredStatus(order.status);
      const currentStatusIndex = orderStatusIndex[currentStatus];
      if (isCancellation) {
        validationError = new AppError(
          'failed-precondition',
          currentStatusIndex >= orderStatusIndex.paid
            ? 'No se puede cancelar un pedido después del pago.'
            : 'La cancelación debe realizarse desde la opción correspondiente.',
        );
        return undefined;
      }
      if (orderStatusIndex[nextStatus] <= currentStatusIndex) {
        validationError = new AppError(
          'failed-precondition',
          'El estado del pedido solo puede avanzar.',
        );
        return undefined;
      }

      validationError = undefined;
      return { ...order, status: nextStatus };
    });

    if (!result.committed) {
      throw (
        validationError ??
        new AppError(
          'failed-precondition',
          'No se pudo actualizar el estado del pedido.',
        )
      );
    }

    const updatedOrder = result.snapshot.val();
    const updates = {
      ['ordersByUser/' + updatedOrder.ownerUid + '/' + orderId]: updatedOrder,
      ['staffQueue/' + orderId]: queuedStatuses.has(nextStatus)
        ? { orderId }
        : null,
    };
    await database.ref().update(updates);

    return { orderId, order: updatedOrder };
  };
}
