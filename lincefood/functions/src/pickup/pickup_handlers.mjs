import { createHash, randomBytes } from 'node:crypto';

import { AppError } from '../app_error.mjs';
import {
  customerOrderView,
  normalizeStoredStatus,
} from '../orders/order_status_rules.mjs';

const pickupTokenTtlMs = 10 * 60 * 1000;
const orderIdPattern = /^[A-Za-z0-9_-]{1,128}$/;
const tokenPattern = /^[A-Za-z0-9_-]{32,128}$/;
const usedTokenMessage = 'Este código ya fue usado.';
const expiredTokenMessage =
  'El código expiró. Pide al cliente que genere uno nuevo.';
const replacedTokenMessage = 'El código fue reemplazado por uno más reciente.';
const deliveryFailedMessage = 'No se pudo completar la entrega. Inténtalo de nuevo.';

// El QR contiene un token aleatorio; la base guarda solo su hash.
export function generatePickupToken() {
  return randomBytes(32).toString('base64url');
}

export function hashPickupToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

function requireUid(request) {
  if (typeof request.auth?.uid !== 'string' || request.auth.uid.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  return request.auth.uid;
}

// El personal y los administradores pueden entregar; se guarda el rol que actuó.
function requireStaff(request) {
  const uid = requireUid(request);
  const isAdmin = request.auth.token?.admin === true;
  if (!isAdmin && request.auth.token?.staff !== true) {
    throw new AppError(
      'permission-denied',
      'Solo el personal puede entregar pedidos.',
    );
  }
  return { uid, role: isAdmin ? 'admin' : 'staff' };
}

function requireOrderId(value) {
  if (typeof value !== 'string' || !orderIdPattern.test(value)) {
    throw new AppError('invalid-argument', 'El pedido no es válido.');
  }
  return value;
}

function requireTokenText(value) {
  if (typeof value !== 'string' || !tokenPattern.test(value)) {
    throw new AppError('invalid-argument', 'El código no es válido.');
  }
  return value;
}

async function readPickupState(database, orderId) {
  const [orderSnapshot, paymentSnapshot] = await Promise.all([
    database.ref('orders/' + orderId).get(),
    database.ref('payments/' + orderId).get(),
  ]);
  return { order: orderSnapshot.val(), payment: paymentSnapshot.val() };
}

// Un pedido solo se recoge si el pago fue confirmado y el estado es listo.
function pickupBlockReason(order, payment) {
  if (payment?.status !== 'succeeded') {
    return 'El pedido todavía no está pagado.';
  }
  if (normalizeStoredStatus(order.status) !== 'ready') {
    return 'El pedido todavía no está listo para recoger.';
  }
  return null;
}

// Emite un QR nuevo para un pedido listo y pagado. El QR anterior queda sin
// efecto porque el pedido solo acepta el token activo.
export function createIssuePickupTokenHandler({
  database,
  now = Date.now,
  generateToken = generatePickupToken,
}) {
  return async (request) => {
    const uid = requireUid(request);
    const orderId = requireOrderId(request.data?.orderId);

    const { order, payment } = await readPickupState(database, orderId);
    if (!order || order.ownerUid !== uid) {
      throw new AppError('not-found', 'No se encontró el pedido.');
    }
    const blockReason = pickupBlockReason(order, payment);
    if (blockReason) {
      throw new AppError('failed-precondition', blockReason);
    }

    const token = generateToken();
    const tokenId = hashPickupToken(token);
    const expiresAt = now() + pickupTokenTtlMs;

    await database.ref().update({
      ['pickupTokens/' + tokenId]: {
        orderId,
        ownerUid: uid,
        expiresAt,
        consumedAt: null,
      },
      ['orders/' + orderId + '/activePickupTokenId']: tokenId,
    });

    return { token, expiresAt };
  };
}

// Reclama el token de forma atómica: solo una transacción puede marcarlo usado.
async function claimPickupToken(tokenRef, now) {
  let rejection;
  const consumedAt = now();
  const claim = await tokenRef.transaction((current) => {
    rejection = undefined;
    if (current === null) return null; // RTDB puede empezar con la caché vacía.
    if (current.consumedAt) {
      rejection = usedTokenMessage;
      return undefined;
    }
    if (current.expiresAt <= consumedAt) {
      rejection = expiredTokenMessage;
      return undefined;
    }
    return { ...current, consumedAt };
  });
  if (!claim.committed || !claim.snapshot.val()) {
    throw new AppError('failed-precondition', rejection ?? usedTokenMessage);
  }
  return consumedAt;
}

// Libera el token solo si sigue reclamado por este intento, para que el
// cliente pueda volver a presentarlo cuando la entrega no se completó.
async function releasePickupToken(tokenRef, consumedAt) {
  await tokenRef.transaction((current) =>
    current && current.consumedAt === consumedAt
      ? { ...current, consumedAt: null }
      : undefined,
  );
}

// Reserva la entrega de un pedido. Solo una operación puede entregarlo, y la
// reserva queda como registro de que ya se entregó.
async function claimDeliveryGate(database, orderId, at) {
  const gate = await database
    .ref('pickupDeliveries/' + orderId)
    .transaction((current) => (current ? undefined : { claimedAt: at }));
  if (!gate.committed) {
    throw new AppError(
      'failed-precondition',
      'Este pedido ya se está entregando o ya fue entregado.',
    );
  }
}

// Solo se libera si la escritura de entrega no se completó.
async function releaseDeliveryGate(database, orderId, at) {
  await database.ref('pickupDeliveries/' + orderId).transaction((current) =>
    current && current.claimedAt === at ? null : undefined,
  );
}

function deliveryEvent({ actor, at, tokenId }) {
  return {
    type: 'status_changed',
    from: 'ready',
    to: 'delivered',
    actorUid: actor.uid,
    actorRole: actor.role,
    at,
    method: 'qr',
    tokenId,
  };
}

// Entrega el pedido en una sola escritura multiubicación: el estado, la
// auditoría, la vista del cliente y la cola cambian juntos o no cambia nada.
// La reserva evita confirmar dos veces la misma entrega.
async function deliverOrder({
  database,
  orderId,
  actor,
  at,
  tokenId,
}) {
  await claimDeliveryGate(database, orderId, at);

  try {
    const { order, payment } = await readPickupState(database, orderId);
    if (!order) {
      throw new AppError('not-found', 'No se encontró el pedido.');
    }
    const blockReason = pickupBlockReason(order, payment);
    if (blockReason) {
      throw new AppError('failed-precondition', blockReason);
    }
    if (order.activePickupTokenId !== tokenId) {
      throw new AppError('failed-precondition', replacedTokenMessage);
    }

    const delivered = {
      ...order,
      status: 'delivered',
      deliveredAt: at,
      deliveredBy: actor.uid,
    };
    const customerView = customerOrderView(delivered);
    delete customerView.activePickupTokenId;

    const eventKey = database.ref('orderEvents/' + orderId).push().key;
    await database.ref().update({
      ['orders/' + orderId + '/status']: 'delivered',
      ['orders/' + orderId + '/deliveredAt']: at,
      ['orders/' + orderId + '/deliveredBy']: actor.uid,
      ['orderEvents/' + orderId + '/' + eventKey]: deliveryEvent({
        actor,
        at,
        tokenId,
      }),
      ['ordersByUser/' + order.ownerUid + '/' + orderId]: customerView,
      ['staffQueue/' + orderId]: null,
    });

    return delivered;
  } catch (error) {
    await releaseDeliveryGate(database, orderId, at);
    if (error instanceof AppError) throw error;
    throw new AppError('internal', deliveryFailedMessage);
  }
}

// Valida el QR y marca el pedido como entregado. Dos escaneos simultáneos
// no pueden ganar: solo la primera transacción reclama el token.
export function createConsumePickupTokenHandler({ database, now = Date.now }) {
  return async (request) => {
    const actor = requireStaff(request);
    const token = requireTokenText(request.data?.token);
    const tokenId = hashPickupToken(token);
    const tokenRef = database.ref('pickupTokens/' + tokenId);

    const record = (await tokenRef.get()).val();
    if (!record) {
      throw new AppError('not-found', 'El código no es válido.');
    }
    if (record.consumedAt) {
      throw new AppError('failed-precondition', usedTokenMessage);
    }
    if (record.expiresAt <= now()) {
      throw new AppError('failed-precondition', expiredTokenMessage);
    }

    const orderId = record.orderId;
    const { order, payment } = await readPickupState(database, orderId);
    if (!order || order.ownerUid !== record.ownerUid) {
      throw new AppError('not-found', 'El código no es válido.');
    }
    const blockReason = pickupBlockReason(order, payment);
    if (blockReason) {
      throw new AppError('failed-precondition', blockReason);
    }

    const consumedAt = await claimPickupToken(tokenRef, now);

    try {
      await deliverOrder({
        database,
        orderId,
        actor,
        at: consumedAt,
        tokenId,
      });
    } catch (error) {
      await releasePickupToken(tokenRef, consumedAt);
      throw error;
    }

    return { orderId, status: 'delivered' };
  };
}

// Las versiones anteriores de la app aún pueden llamar al endpoint del folio.
export function requirePickupQr(request) {
  requireStaff(request);
  throw new AppError('failed-precondition', 'Escanea el QR del estudiante para entregar el pedido.');
}
