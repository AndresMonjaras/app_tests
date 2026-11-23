import test from 'node:test';
import assert from 'node:assert/strict';

import { AppError } from '../src/app_error.mjs';
import {
  requirePickupQr,
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
  let pushCount = 0;

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
      key: segments(path).at(-1) ?? null,
      child(key) {
        return ref([path, key].filter(Boolean).join('/'));
      },
      push() {
        pushCount += 1;
        return { key: 'push' + String(pushCount).padStart(4, '0') };
      },
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
        return { committed: true, snapshot: { val: () => clone(next), exists: () => next !== null } };
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

// Un pedido listo se siembra con pago confirmado salvo que la prueba diga otra cosa.
function seedPaid(initial) {
  const seeded = { ...initial };
  for (const key of Object.keys(initial)) {
    const match = /^orders\/([^/]+)$/.exec(key);
    if (match && !(`payments/${match[1]}` in initial)) {
      seeded[`payments/${match[1]}`] = { status: 'succeeded' };
    }
  }
  return seeded;
}

const staff = { uid: 'staff1', token: { staff: true } };
const owner = { uid: 'alumno1', token: {} };

function readyOrder(overrides = {}) {
  return {
    ownerUid: 'alumno1',
    status: 'ready',
    totalCents: 5000,
    folio: 'LF-ABCD1234',
    ...overrides,
  };
}

function createDatabase(initial = {}) {
  return createFakeDatabase(seedPaid({ 'orders/ord1': readyOrder(), ...initial }));
}

async function issueToken(database, orderId = 'ord1', now = () => 1_000) {
  const issue = createIssuePickupTokenHandler({ database, now });
  return issue({ auth: owner, data: { orderId } });
}

function assertAppError(code) {
  return (error) => error instanceof AppError && error.code === code;
}

test('el dueño recibe un QR y la base solo guarda su hash', async () => {
  const database = createDatabase();

  const { token, expiresAt } = await issueToken(database);

  assert.equal(expiresAt, 1_000 + 20 * 60 * 1000);
  const tokenId = hashPickupToken(token);
  assert.equal(database.store.has('pickupTokens/' + tokenId), true);
  assert.equal(database.store.has('pickupTokens/' + token), false);
  assert.equal(database.store.get('orders/ord1').activePickupTokenId, tokenId);
});

test('no se emite QR para un pedido ajeno, no listo o no pagado', async () => {
  const database = createDatabase({
    'orders/ord2': readyOrder({ status: 'preparing' }),
    'orders/ord3': readyOrder(),
    'payments/ord3': { status: 'pending' },
    'orders/ord4': readyOrder({ ownerUid: 'otro' }),
  });
  const issue = createIssuePickupTokenHandler({ database, now: () => 1 });

  await assert.rejects(
    issue({ auth: owner, data: { orderId: 'ord4' } }),
    assertAppError('not-found'),
  );
  await assert.rejects(
    issue({ auth: owner, data: { orderId: 'ord2' } }),
    assertAppError('failed-precondition'),
  );
  await assert.rejects(
    issue({ auth: owner, data: { orderId: 'ord3' } }),
    assertAppError('failed-precondition'),
  );
});

test('un pedido con estado guardado en español también puede emitir QR', async () => {
  const database = createDatabase({ 'orders/ord1': readyOrder({ status: 'listo' }) });

  const { token } = await issueToken(database);

  assert.equal(typeof token, 'string');
});

test('el personal entrega el pedido una sola vez y deja auditoría', async () => {
  const database = createDatabase({ 'staffQueue/ord1': { orderId: 'ord1' } });
  const { token } = await issueToken(database);
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  const result = await consume({ auth: staff, data: { token } });

  assert.deepEqual(result, { orderId: 'ord1', status: 'delivered' });
  const order = database.store.get('orders/ord1');
  assert.equal(order.status, 'delivered');
  assert.equal(order.deliveredAt, 2_000);
  assert.equal(order.deliveredBy, staff.uid);
  assert.equal(database.store.has('staffQueue/ord1'), false);

  const events = Object.values(database.store.get('orderEvents/ord1'));
  assert.equal(events.length, 1);
  assert.deepEqual(events[0], {
    type: 'status_changed',
    from: 'ready',
    to: 'delivered',
    actorUid: staff.uid,
    actorRole: 'staff',
    at: 2_000,
    method: 'qr',
    tokenId: hashPickupToken(token),
  });

  const customerView = database.store.get('ordersByUser/alumno1/ord1');
  assert.equal(customerView.status, 'delivered');
  assert.equal(customerView.deliveredBy, undefined);

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    assertAppError('failed-precondition'),
  );
  assert.equal(Object.keys(database.store.get('orderEvents/ord1')).length, 1);
});

test('dos escaneos simultáneos no entregan dos veces', async () => {
  const database = createDatabase();
  const { token } = await issueToken(database);
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  const results = await Promise.allSettled([
    consume({ auth: staff, data: { token } }),
    consume({ auth: staff, data: { token } }),
  ]);

  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  const rejected = results.find((r) => r.status === 'rejected');
  assert.ok(assertAppError('failed-precondition')(rejected.reason));
  assert.equal(Object.keys(database.store.get('orderEvents/ord1')).length, 1);
});

test('si el estado cambia durante el canje, la transacción revalida antes de entregar', async () => {
  const base = createDatabase();
  const { token } = await issueToken(base);
  const database = {
    ref(path = '') {
      const ref = base.ref(path);
      if (path !== '') return ref;
      return {
        ...ref,
        async transaction(update) {
          update((await ref.get()).val());
          await ref.update({ 'orders/ord1/status': 'incident' });
          return ref.transaction(update);
        },
      };
    },
  };
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    (error) =>
      assertAppError('failed-precondition')(error) &&
      error.message === 'El pedido todavía no está listo para recoger.',
  );
  assert.equal(base.store.get('orders/ord1').status, 'incident');
  assert.equal(base.store.has('orderEvents/ord1'), false);
  assert.equal(base.store.get('pickupTokens/' + hashPickupToken(token)).consumedAt, null);
});

test('un QR expirado no entrega el pedido', async () => {
  const database = createDatabase();
  const { token, expiresAt } = await issueToken(database);
  const consume = createConsumePickupTokenHandler({
    database,
    now: () => expiresAt,
  });

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    assertAppError('failed-precondition'),
  );
  assert.equal(database.store.get('orders/ord1').status, 'ready');
  assert.equal(database.store.has('orderEvents/ord1'), false);
});

test('regenerar el QR invalida el anterior y no consume el pedido', async () => {
  const database = createDatabase();
  const first = await issueToken(database);
  const second = await issueToken(database);
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  await assert.rejects(
    consume({ auth: staff, data: { token: first.token } }),
    assertAppError('failed-precondition'),
  );
  assert.equal(database.store.get('orders/ord1').status, 'ready');
  const firstId = hashPickupToken(first.token);
  assert.equal(database.store.get('pickupTokens/' + firstId).consumedAt, null);

  const result = await consume({ auth: staff, data: { token: second.token } });
  assert.equal(result.status, 'delivered');
});

test('un token de otro pedido no entrega al pedido que se escanea', async () => {
  const database = createDatabase({ 'orders/ord2': readyOrder() });
  const tokenForOrd2 = await issueToken(database, 'ord2');
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  const result = await consume({ auth: staff, data: { token: tokenForOrd2.token } });

  assert.equal(result.orderId, 'ord2');
  assert.equal(database.store.get('orders/ord1').status, 'ready');
  assert.equal(database.store.get('orders/ord2').status, 'delivered');
});

test('un token cuyo dueño no coincide con el pedido no entrega nada', async () => {
  const database = createDatabase();
  const { token } = await issueToken(database);
  await database.ref().update({
    ['pickupTokens/' + hashPickupToken(token) + '/ownerUid']: 'otro',
  });
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    assertAppError('not-found'),
  );
  assert.equal(database.store.get('orders/ord1').status, 'ready');
});

test('un pedido que no está listo no registra evento de entrega', async () => {
  const database = createDatabase();
  const { token } = await issueToken(database);
  await database.ref().update({
    'orders/ord1/status': 'preparing',
  });
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });
  const tokenId = hashPickupToken(token);

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    assertAppError('failed-precondition'),
  );
  assert.equal(database.store.has('orderEvents/ord1'), false);
  assert.equal(database.store.get('pickupTokens/' + tokenId).consumedAt, null);
});

test('un pedido que dejó de estar pagado no entrega aunque tenga QR', async () => {
  const database = createDatabase();
  const { token } = await issueToken(database);
  await database.ref().update({ 'payments/ord1/status': 'failed' });
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    (error) =>
      assertAppError('failed-precondition')(error) &&
      error.message === 'El pedido todavía no está pagado.',
  );
  assert.equal(database.store.get('orders/ord1').status, 'ready');
});

test('si la escritura de la entrega falla, nada cambia y el QR se puede reintentar', async () => {
  const base = createDatabase();
  const { token } = await issueToken(base);
  let failWrites = true;
  // La transacción falla antes de escribir.
  const database = {
    ref(path = '') {
      const ref = base.ref(path);
      if (path !== '') return ref;
      return {
        ...ref,
        transaction: async (update) => {
          if (failWrites) throw new Error('sin conexión');
          return ref.transaction(update);
        },
      };
    },
  };
  const consume = createConsumePickupTokenHandler({ database, now: () => 2_000 });

  await assert.rejects(
    consume({ auth: staff, data: { token } }),
    assertAppError('internal'),
  );
  assert.equal(base.store.get('orders/ord1').status, 'ready');
  assert.equal(base.store.has('orderEvents/ord1'), false);
  assert.equal(base.store.has('pickupDeliveries/ord1'), false);
  assert.equal(base.store.get('pickupTokens/' + hashPickupToken(token)).consumedAt, null);

  failWrites = false;
  const result = await consume({ auth: staff, data: { token } });
  assert.equal(result.status, 'delivered');
  assert.equal(Object.keys(base.store.get('orderEvents/ord1')).length, 1);
});

test('un token que no existe no entrega nada', async () => {
  const database = createDatabase();
  const consume = createConsumePickupTokenHandler({ database, now: () => 1 });

  await assert.rejects(
    consume({ auth: staff, data: { token: 'a'.repeat(43) } }),
    assertAppError('not-found'),
  );
});

test('solo el personal puede entregar y el formato del código se valida', async () => {
  const database = createDatabase();
  const consume = createConsumePickupTokenHandler({ database, now: () => 1 });

  await assert.rejects(
    consume({ auth: owner, data: { token: 'a'.repeat(43) } }),
    assertAppError('permission-denied'),
  );
  await assert.rejects(
    consume({ auth: staff, data: { token: 'corto' } }),
    assertAppError('invalid-argument'),
  );
});

test('el administrador puede entregar por QR aunque el reclamo empiece con caché fría', async () => {
  const base = createDatabase();
  const { token } = await issueToken(base);
  const database = {
    ref(path = '') {
      const reference = base.ref(path);
      if (path !== '') return reference;
      return {
        ...reference,
        async transaction(update) {
          assert.equal(update(null), null);
          return reference.transaction(update);
        },
      };
    },
  };
  const consume = createConsumePickupTokenHandler({ database, now: () => 2000 });
  const result = await consume({ auth: { uid: 'admin', token: { admin: true } }, data: { token } });
  assert.equal(result.status, 'delivered');
  assert.equal(base.store.get('orders/ord1').deliveredBy, 'admin');
});

test('el endpoint de folio exige QR incluso a personal y administración', () => {
  for (const auth of [staff, { uid: 'admin', token: { admin: true } }]) {
    assert.throws(
      () => requirePickupQr({ auth, data: { folio: 'LF-ABCD1234' } }),
      { code: 'failed-precondition', message: /Escanea el QR/ },
    );
  }
  assert.throws(() => requirePickupQr({ auth: owner }), { code: 'permission-denied' });
  assert.throws(() => requirePickupQr({}), { code: 'unauthenticated' });
});
