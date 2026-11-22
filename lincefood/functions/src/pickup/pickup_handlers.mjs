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
  if (order.isCancelled === true || normalizeStoredStatus(order.status) !== 'ready') {
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

// La raíz es el ancestro común del pago, el token y las vistas del pedido.
export function createConsumePickupTokenHandler({ database, now = Date.now }) {
  return async (request) => {
    const actor = requireStaff(request);
    const tokenId = hashPickupToken(requireTokenText(request.data?.token));
    const root = database.ref();
    const eventKey = root.child('orderEvents').push().key;
    let rejection;
    let deliveredOrderId;

    try {
      const result = await root.transaction((current) => {
        rejection = undefined;
        deliveredOrderId = undefined;
        if (current === null) return null;

        const token = current.pickupTokens?.[tokenId];
        const orderId = token?.orderId;
        const order = current.orders?.[orderId];
        if (!token || !order || order.ownerUid !== token.ownerUid) {
          rejection = new AppError('not-found', 'El código no es válido.');
          return undefined;
        }

        const at = now();
        let reason;
        if (token.consumedAt != null) {
          reason = usedTokenMessage;
        } else if (token.expiresAt <= at) {
          reason = expiredTokenMessage;
        } else {
          reason = pickupBlockReason(order, current.payments?.[orderId]);
          if (!reason && order.activePickupTokenId !== tokenId) {
            reason = replacedTokenMessage;
          }
        }
        if (reason) {
          rejection = new AppError('failed-precondition', reason);
          return undefined;
        }

        const delivered = {
          ...order,
          status: 'delivered',
          deliveredAt: at,
          deliveredBy: actor.uid,
        };
        delete delivered.activePickupTokenId;

        current.orders[orderId] = delivered;
        current.pickupTokens[tokenId] = { ...token, consumedAt: at };
        const history = (current.ordersByUser ??= {});
        (history[order.ownerUid] ??= {})[orderId] = customerOrderView(delivered);
        const events = (current.orderEvents ??= {});
        (events[orderId] ??= {})[eventKey] = deliveryEvent({ actor, at, tokenId });
        if (current.staffQueue) delete current.staffQueue[orderId];

        deliveredOrderId = orderId;
        return current;
      });

      if (!result.committed || !deliveredOrderId || !result.snapshot.exists()) {
        throw rejection ?? new AppError('not-found', 'El código no es válido.');
      }
      return { orderId: deliveredOrderId, status: 'delivered' };
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('internal', deliveryFailedMessage);
    }
  };
}

// Las versiones anteriores de la app aún pueden llamar al endpoint del folio.
export function requirePickupQr(request) {
  requireStaff(request);
  throw new AppError('failed-precondition', 'Escanea el QR del estudiante para entregar el pedido.');
}
