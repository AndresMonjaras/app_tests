import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { createStripeWebhookHandler } from '../src/handlers.mjs';
import { createMembershipPaymentIntentHandler } from '../src/memberships/membership_handlers.mjs';

const now = Date.UTC(2026, 10, 22);
const dayMs = 86_400_000;
const uid = 'user-1';
const planId = 'campus_pro';
const membershipPath = `memberships/${uid}`;
const paymentPath = (id) => `membershipPayments/${uid}/${id}`;
const seed = JSON.parse(readFileSync(
  new URL('../../firebase/seeds/membershipPlans.seed.json', import.meta.url),
));

function fakeDatabase(initial = seed) {
  const data = structuredClone(initial);
  const read = (path) => path.split('/').reduce((node, key) => node?.[key], data) ?? null;
  const write = (path, value) => {
    const keys = path.split('/');
    const last = keys.pop();
    let node = data;
    for (const key of keys) node = node[key] ??= {};
    node[last] = structuredClone(value);
  };
  const snapshot = (value) => ({ val: () => structuredClone(value), exists: () => value != null });
  const database = {
    ref(path) {
      return {
        get: async () => snapshot(read(path)),
        child: (key) => database.ref(`${path}/${key}`),
        set: async (value) => write(path, value),
        transaction: async (update) => {
          assert.equal(update(null), null, 'Debe permitir que RTDB resuelva una caché fría');
          const current = read(path);
          const next = current === null ? null : update(structuredClone(current));
          if (next != null) write(path, next);
          return { snapshot: snapshot(read(path)) };
        },
      };
    },
  };
  return { database, read, write };
}

function checkout(database, { id = 'pi_first', status = 'requires_payment_method' } = {}) {
  let options;
  let intent;
  const handler = createMembershipPaymentIntentHandler({
    database,
    now: () => now,
    stripe: {
      paymentIntents: {
        create: async (params, requestOptions) => {
          options = requestOptions;
          intent = { ...params, id, status, livemode: false, client_secret: 'fake_client_secret' };
          return intent;
        },
      },
    },
  });
  return {
    handler,
    pay: (period) => handler({ auth: { uid }, data: { planId, period } }),
    intent: () => intent,
    options: () => options,
  };
}

async function deliver(database, intent, eventOverrides = {}) {
  const event = {
    type: 'payment_intent.succeeded',
    livemode: false,
    data: { object: { ...intent, amount_received: intent.amount } },
    ...eventOverrides,
  };
  const webhook = createStripeWebhookHandler({
    database,
    stripe: { webhooks: { constructEvent: () => event } },
    webhookSecret: 'fake_webhook_secret',
  });
  const response = {
    status(code) { this.code = code; return this; },
    send(body) { this.body = body; },
  };
  await webhook({ rawBody: Buffer.from('{}'), get: () => 'fake_signature' }, response);
  return response;
}

test('la callable usa el precio RTDB, metadata de membresía y una clave diaria', async () => {
  const { database, read, write } = fakeDatabase();
  write('membershipPlans/campus_pro/prices/weekly', 1700);
  const payment = checkout(database);
  const result = await payment.handler({
    auth: { uid },
    data: { planId, period: 'weekly', amount: 1, currency: 'usd', uid: 'someone-else' },
  });
  const intent = payment.intent();
  assert.equal(intent.amount, 1700);
  assert.equal(intent.currency, 'mxn');
  assert.deepEqual(intent.metadata, { uid, planId, period: 'weekly', type: 'membership' });
  assert.equal(payment.options().idempotencyKey, 'membership:user-1:campus_pro:weekly:2026-11-22');
  assert.deepEqual(result, { clientSecret: 'fake_client_secret', paymentIntentId: 'pi_first' });
  assert.deepEqual(read(paymentPath(intent.id)), {
    uid, planId, period: 'weekly', amount: 1700, currency: 'mxn', status: 'requires_payment',
  });
});

test('la callable requiere autenticación y rechaza planes, modalidades y precios inválidos', async () => {
  const { database, write } = fakeDatabase();
  const payment = checkout(database);
  await assert.rejects(payment.handler({}), { code: 'unauthenticated' });
  await assert.rejects(payment.handler({
    auth: { uid },
    data: { planId: 'basico', period: 'weekly' },
  }), { code: 'invalid-argument' });
  await assert.rejects(payment.pay('__proto__'), { code: 'invalid-argument' });
  write('membershipPlans/campus_pro/prices/weekly', '1500');
  await assert.rejects(payment.pay('weekly'), { code: 'failed-precondition' });
  assert.equal(payment.intent(), undefined);
});

test('el webhook activa por 7 días y extiende otros 30 sin volver a aplicar el primer cobro', async () => {
  const { database, read, write } = fakeDatabase();
  const first = checkout(database);
  await first.pay('weekly');
  write('membershipPlans/campus_pro/prices/weekly', 1800);
  const activation = await deliver(database, first.intent());
  assert.equal(activation.code, 200);
  assert.equal(activation.body, 'OK');
  const initial = read(membershipPath);
  assert.equal(initial.planId, planId);
  assert.equal(initial.period, 'weekly');
  assert.equal(initial.status, 'active');
  assert.equal(initial.expiresAt - initial.startsAt, 7 * dayMs);
  assert.equal(read(paymentPath(first.intent().id)).status, 'succeeded');
  await deliver(database, first.intent());
  assert.deepEqual(read(membershipPath), initial);

  const second = checkout(database, { id: 'pi_second' });
  await second.pay('monthly');
  await deliver(database, second.intent());
  const extended = read(membershipPath);
  assert.equal(extended.period, 'monthly');
  assert.equal(extended.startsAt, initial.startsAt);
  assert.equal(extended.expiresAt, initial.expiresAt + 30 * dayMs);

  // Simula una entrega repetida cuando la confirmación de ese pago quedó pendiente.
  write(`${paymentPath(first.intent().id)}/status`, 'requires_payment');
  await deliver(database, first.intent());
  assert.deepEqual(read(membershipPath), extended);
  assert.equal(read(paymentPath(first.intent().id)).status, 'succeeded');
});

test('el webhook rechaza importes, moneda, metadata y eventos fuera de Sandbox', async () => {
  const { database, read } = fakeDatabase();
  const payment = checkout(database);
  await payment.pay('weekly');
  const intent = payment.intent();
  for (const bad of [
    { ...intent, amount: intent.amount - 1 },
    { ...intent, currency: 'usd' },
    { ...intent, metadata: { ...intent.metadata, period: 'monthly' } },
    { ...intent, livemode: true },
  ]) {
    assert.equal((await deliver(database, bad)).body, 'El cobro no coincide con la membresía.');
  }
  const partialCapture = await deliver(database, intent, {
    data: { object: { ...intent, amount_received: intent.amount - 1 } },
  });
  assert.equal(partialCapture.body, 'El cobro no coincide con la membresía.');
  assert.equal((await deliver(database, intent, { livemode: true })).code, 400);
  assert.equal((await deliver(database, intent, { type: 'payment_intent.payment_failed' })).code, 200);
  assert.equal(read(membershipPath), null);
  assert.equal(read(paymentPath(intent.id)).status, 'requires_payment');
});

test('una membresía de por vida no vence ni se sobrescribe al llegar un pago temporal', async () => {
  const { database, read } = fakeDatabase();
  const temporary = checkout(database, { id: 'pi_weekly' });
  const lifetime = checkout(database, { id: 'pi_lifetime' });
  await temporary.pay('weekly');
  await lifetime.pay('lifetime');

  await deliver(database, lifetime.intent());
  const active = read(membershipPath);
  assert.equal(active.period, 'lifetime');
  assert.equal(active.expiresAt, null);
  assert.equal(active.paymentIntentId, 'pi_lifetime');

  await deliver(database, temporary.intent());
  const after = read(membershipPath);
  assert.deepEqual(after, {
    ...active,
    appliedPayments: { pi_lifetime: true, pi_weekly: true },
  });
  await assert.rejects(temporary.pay('weekly'), { code: 'failed-precondition' });
});
