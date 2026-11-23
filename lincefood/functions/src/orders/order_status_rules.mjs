import { AppError } from '../app_error.mjs';

const knownStatuses = new Set([
  'payment_pending',
  'paid',
  'confirmed',
  'preparing',
  'ready',
  'delivered',
  'incident',
  'cancelled',
  'rejected',
]);

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
  rechazado: 'rejected',
  cancelado: 'cancelled',
  cancelled: 'cancelled',
};

// Cada paso del personal solo puede avanzar al siguiente del flujo.
// La entrega no forma parte de este mapa: solo ocurre al validar el QR de recogida.
export const nextStaffStatus = {
  paid: 'confirmed',
  confirmed: 'preparing',
  preparing: 'ready',
};

// Solo se puede cancelar mientras el pago sigue pendiente.
export const cancellableStatuses = new Set(['payment_pending']);

// Estados en los que un pedido ya pagado puede pasar a incidencia.
export const activeStatuses = new Set([
  'paid',
  'confirmed',
  'preparing',
  'ready',
]);

// La cola del personal incluye la incidencia hasta que un administrador la resuelve.
export const queuedStatuses = new Set([
  'paid',
  'confirmed',
  'preparing',
  'ready',
  'incident',
]);

// Campos de fecha y operador que se guardan al entrar en cada estado.
export const stampFieldsByStatus = {
  confirmed: { at: 'confirmedAt', by: 'confirmedBy' },
  preparing: { at: 'preparingAt', by: 'preparingBy' },
  ready: { at: 'readyAt', by: 'readyBy' },
  delivered: { at: 'deliveredAt', by: 'deliveredBy' },
  incident: { at: 'incidentAt', by: 'incidentBy' },
};

export function normalizeStoredStatus(value) {
  const status = String(value ?? '').trim().toLowerCase();
  if (knownStatuses.has(status)) return status;
  return storedStatusAliases[status] ?? 'payment_pending';
}

export function requireUid(request) {
  if (typeof request.auth?.uid !== 'string' || request.auth.uid.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  return request.auth.uid;
}

export function requireStaff(request) {
  const uid = requireUid(request);
  const isAdmin = request.auth.token?.admin === true;
  if (!isAdmin && request.auth.token?.staff !== true) {
    throw new AppError(
      'permission-denied',
      'Solo el personal puede actualizar el estado de un pedido.',
    );
  }
  return { uid, role: isAdmin ? 'admin' : 'staff' };
}

export function requireAdmin(request) {
  const uid = requireUid(request);
  if (request.auth.token?.admin !== true) {
    throw new AppError(
      'permission-denied',
      'Solo administración puede gestionar incidencias.',
    );
  }
  return { uid, role: 'admin' };
}

export function requireOrderId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new AppError('invalid-argument', 'El pedido no es válido.');
  }
  return value;
}

export function requireNote(value, message) {
  const note = typeof value === 'string' ? value.trim() : '';
  if (note.length === 0 || note.length > 200) {
    throw new AppError('invalid-argument', message);
  }
  return note;
}

export function requireOrderObject(order) {
  if (!order || typeof order !== 'object' || Array.isArray(order)) {
    throw new AppError('not-found', 'No se encontró el pedido.');
  }
  if (typeof order.ownerUid !== 'string' || order.ownerUid.length === 0) {
    throw new AppError(
      'failed-precondition',
      'El pedido no tiene un propietario válido.',
    );
  }
  if (order.isCancelled === true) {
    throw new AppError(
      'failed-precondition',
      'Un pedido cancelado no puede cambiar.',
    );
  }
  return order;
}

const internalFields = [
  'paidPaymentIntentId',
  'confirmedBy',
  'preparingBy',
  'readyBy',
  'deliveredBy',
  'incidentBy',
  'incidentResolvedBy',
  'rejectedBy',
  'rejectionPendingFrom',
];

// El ticket omite las referencias internas del pago y del personal.
export function customerOrderView(order) {
  const view = { ...order };
  for (const field of internalFields) delete view[field];
  return view;
}
