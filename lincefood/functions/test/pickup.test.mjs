import test from 'node:test';
import assert from 'node:assert/strict';

import { AppError } from '../src/app_error.mjs';
import {
  createConsumePickupTokenHandler,
  createIssuePickupTokenHandler,
  hashPickupToken,
} from '../src/pickup/pickup_handlers.mjs';

// Base en memoria con árbol anidado, como Realtime Database.
// Expone `store` para que las pruebas lean rutas completas.
function createFakeDatabase(initial = {}) {
  const tree = {};
  const clone = (value) => (value === undefined ? null : structuredClone(value));
  const segments = (path) => path.split('/').filter(Boolean);

  function read(path) {
    let node = tree;
    for (const key of segments(path)) {
      if (node === null || typeof node !== 'object') return null;
      node = node[key];
    }
    return node ?? null;
  }

  function write(path, value) {
    const keys = segments(path);
    if (keys.length === 0) {
      for (const key of Object.keys(tree)) delete tree[key];
      if (value && typeof value === 'object') Object.assign(tree, clone(value));
      return;
    }
    let node = tree;
    for (const key of keys.slice(0, -1)) {
      if (node[key] === null || typeof node[key] !== 'object') node[key] = {};
      node = node[key];
    }
    const last = keys.at(-1);
    if (value === null) delete node[last];
    else node[last] = clone(value);
  }

  function ref(path = '') {
    return {
      async get() {
        const value = clone(read(path));
        return { val: () => value };
      },
      async transaction(update) {
        const current = clone(read(path));
        const next = update(current);
        if (next === undefined) {
          return { committed: false, snapshot: { val: () => current } };
        }
        write(path, next);
        return { committed: true, snapshot: { val: () => clone(next) } };
      },
      async update(changes) {
        for (const [key, value] of Object.entries(changes)) write(key, value);
      },
    };
  }

  for (const [path, value] of Object.entries(initial)) write(path, value);

  const store = {
    get: (path) => clone(read(path)),
    has: (path) => read(path) !== null,
  };

  return { ref, store };
}

const staff = { uid: 'staff1', token: { staff: true } };
const owner = { uid: 'alumno1', token: {} };

function readyOrder(overrides = {}) {
  return {
    ownerUid: 'alumno1',
    status: 'ready',
    totalCents: 5000,
    ...overrides,
  };
}

async function issueToken(database, now = () => 1_000) {
  const issue = createIssuePickupTokenHandler({ database, now });
  return issue({ auth: owner, data: { orderId: 'ord1' } });
}

test('el dueño recibe un QR y la base solo guarda su hash', async () => {
  const database = createFakeDatabase({ 'orders/ord1': readyOrder() });

  const { token, expiresAt } = await issueToken(database);

  assert.equal(expiresAt, 1_000 + 10 * 60 * 1000);
  const tokenId = hashPickupToken(token);
  assert.equal(database.store.has('pickupTokens/' + tokenId), true);
  assert.equal(database.store.has('pickupTokens/' + token), false);
  assert.equal(database.store.get('orders/ord1').activePickupTokenId, tokenId);
});

test('no se emite QR para un pedido ajeno ni para uno que no está listo', async () => {
  const database = createFakeDatabase({
    'orders/ord1': readyOrder({ ownerUid: 'otro' }),
    'orders/ord2': readyOrder({ status: 'preparing' }),
  });
  const issue = createIssuePickupTokenHandler({ database, now: () => 1 });

  await assert.rejects(
    issue({ auth: owner, data: { orderId: 'ord1' } }),
    (error) => error instanceof AppError && error.code === 'not-found',
  );
  await assert.rejects(
    issue({ auth: owner, data: { orderId: 'ord2' } }),
    (error) => error instanceof AppError && error.code === 'failed-precondition',
  );
});

test('el personal entrega el pedido una sola vez con el QR válido', async () => {
  const database = createFakeDatabase({ 'orders/ord1': readyOrder() });
  const { token } = await issueToken(database);
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  const result = await consume({ auth: staff, data: { token } });

  assert.deepEqual(result, { orderId: 'ord1', status: 'delivered' });
  assert.equal(database.store.get('orders/ord1').status, 'delivered');
  assert.equal(database.store.get('orders/ord1').deliveredAt, 2_000);
  const tokenId = hashPickupToken(token);
  assert.deepEqual(database.store.get('orderEvents/ord1/' + tokenId), {
    type: 'pickup_delivered',
    actorUid: staff.uid,
    tokenId,
    createdAt: 2_000,
  });

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    (error) => error instanceof AppError && error.code === 'failed-precondition',
  );
});

test('dos escaneos simultáneos no entregan dos veces', async () => {
  const database = createFakeDatabase({ 'orders/ord1': readyOrder() });
  const { token } = await issueToken(database);
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  const results = await Promise.allSettled([
    consume({ auth: staff, data: { token } }),
    consume({ auth: staff, data: { token } }),
  ]);

  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
});

test('un QR expirado no entrega el pedido', async () => {
  const database = createFakeDatabase({ 'orders/ord1': readyOrder() });
  const { token, expiresAt } = await issueToken(database);
  const consume = createConsumePickupTokenHandler({
    database,
    now: () => expiresAt,
  });

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    (error) => error instanceof AppError && error.code === 'failed-precondition',
  );
  assert.equal(database.store.get('orders/ord1').status, 'ready');
});

test('un QR reemplazado por uno nuevo deja de servir y no consume el pedido', async () => {
  const database = createFakeDatabase({ 'orders/ord1': readyOrder() });
  const first = await issueToken(database);
  await issueToken(database);
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  await assert.rejects(
    consume({ auth: staff, data: { token: first.token } }),
    (error) => error instanceof AppError && error.code === 'failed-precondition',
  );
  assert.equal(database.store.get('orders/ord1').status, 'ready');
  const firstId = hashPickupToken(first.token);
  assert.equal(database.store.get('pickupTokens/' + firstId).consumedAt, null);
});

test('un pedido que no está listo no registra evento de entrega', async () => {
  const database = createFakeDatabase({ 'orders/ord1': readyOrder() });
  const { token } = await issueToken(database);
  await database.ref().update({
    'orders/ord1/status': 'preparing',
  });
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });
  const tokenId = hashPickupToken(token);

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    (error) => error instanceof AppError && error.code === 'failed-precondition',
  );
  assert.equal(database.store.has('orderEvents/ord1/' + tokenId), false);
});

test('un token que no existe no entrega nada', async () => {
  const database = createFakeDatabase({ 'orders/ord1': readyOrder() });
  const consume = createConsumePickupTokenHandler({ database, now: () => 1 });

  await assert.rejects(
    consume({ auth: staff, data: { token: 'a'.repeat(43) } }),
    (error) => error instanceof AppError && error.code === 'not-found',
  );
});

test('solo el personal puede entregar y el formato del código se valida', async () => {
  const database = createFakeDatabase({ 'orders/ord1': readyOrder() });
  const consume = createConsumePickupTokenHandler({ database, now: () => 1 });

  await assert.rejects(
    consume({ auth: owner, data: { token: 'a'.repeat(43) } }),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
  await assert.rejects(
    consume({ auth: staff, data: { token: 'corto' } }),
    (error) => error instanceof AppError && error.code === 'invalid-argument',
  );
});
