import { createHash, randomBytes } from 'node:crypto';

import { AppError } from '../app_error.mjs';

const pickupTokenTtlMs = 10 * 60 * 1000;
const orderIdPattern = /^[A-Za-z0-9_-]{1,128}$/;
const tokenPattern = /^[A-Za-z0-9_-]{32,128}$/;

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

function requireStaff(request) {
  requireUid(request);
  if (
    request.auth.token?.staff !== true &&
    request.auth.token?.admin !== true
  ) {
    throw new AppError(
      'permission-denied',
      'Solo el personal puede entregar pedidos.',
    );
  }
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

// Emite un QR nuevo para un pedido listo. El QR anterior queda sin efecto
// porque el pedido solo acepta el token activo.
export function createIssuePickupTokenHandler({
  database,
  now = Date.now,
  generateToken = generatePickupToken,
}) {
  return async (request) => {
    const uid = requireUid(request);
    const orderId = requireOrderId(request.data?.orderId);

    const snapshot = await database.ref('orders/' + orderId).get();
    const order = snapshot.val();
    if (!order || order.ownerUid !== uid) {
      throw new AppError('not-found', 'No se encontró el pedido.');
    }
    if (order.status !== 'ready') {
      throw new AppError(
        'failed-precondition',
        'El pedido todavía no está listo para recoger.',
      );
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

// Valida el QR y marca el pedido como entregado. Dos escaneos simultáneos
// no pueden ganar: solo la primera transacción reclama el token.
export function createConsumePickupTokenHandler({ database, now = Date.now }) {
  return async (request) => {
    requireStaff(request);
    const token = requireTokenText(request.data?.token);
    const tokenId = hashPickupToken(token);
    const tokenRef = database.ref('pickupTokens/' + tokenId);

    const tokenSnapshot = await tokenRef.get();
    const record = tokenSnapshot.val();
    if (!record) {
      throw new AppError('not-found', 'El código no es válido.');
    }
    if (record.consumedAt) {
      throw new AppError('failed-precondition', 'Este código ya fue usado.');
    }
    if (record.expiresAt <= now()) {
      throw new AppError(
        'failed-precondition',
        'El código expiró. Pide al cliente que genere uno nuevo.',
      );
    }

    const consumedAt = now();
    const claim = await tokenRef.transaction((current) => {
      if (!current || current.consumedAt) return undefined;
      return { ...current, consumedAt };
    });
    if (!claim.committed) {
      throw new AppError('failed-precondition', 'Este código ya fue usado.');
    }

    const orderId = record.orderId;
    let rejectionMessage;
    const orderResult = await database
      .ref('orders/' + orderId)
      .transaction((order) => {
        rejectionMessage = undefined;
        if (!order) {
          rejectionMessage = 'No se encontró el pedido.';
          return undefined;
        }
        if (order.activePickupTokenId !== tokenId) {
          rejectionMessage = 'El código fue reemplazado por uno más reciente.';
          return undefined;
        }
        if (order.status !== 'ready') {
          rejectionMessage = 'El pedido no está listo para entregarse.';
          return undefined;
        }
        return { ...order, status: 'delivered', deliveredAt: consumedAt };
      });

    if (!orderResult.committed) {
      // Se libera el token para que el cliente pueda intentar de nuevo
      // si el problema era solo del pedido.
      await tokenRef.transaction((current) =>
        current && current.consumedAt === consumedAt
          ? { ...current, consumedAt: null }
          : undefined,
      );
      throw new AppError(
        'failed-precondition',
        rejectionMessage ?? 'No se pudo entregar el pedido.',
      );
    }

    const deliveredOrder = orderResult.snapshot.val();
    await database.ref().update({
      ['ordersByUser/' + deliveredOrder.ownerUid + '/' + orderId]: deliveredOrder,
      ['staffQueue/' + orderId]: null,
      ['orderEvents/' + orderId + '/' + tokenId]: {
        type: 'pickup_delivered',
        actorUid: request.auth.uid,
        tokenId,
        createdAt: consumedAt,
      },
    });

    return { orderId, status: 'delivered' };
  };
}
