import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createCreateOrderHandler,
  createCreatePaymentIntentHandler,
  createStripeWebhookHandler,
} from '../src/handlers.mjs';
import { createUpdateOrderStatusHandler } from '../src/orders/update_order_status_handler.mjs';

function createMemoryDatabase(initial = {}) {
  const data = structuredClone(initial);

  function getAt(path) {
    return path
      .split('/')
      .filter(Boolean)
      .reduce((value, key) => value?.[key], data);
  }

  function setAt(path, value) {
    const parts = path.split('/').filter(Boolean);
    const last = parts.pop();
    const parent = parts.reduce((current, key) => {
      current[key] ??= {};
      return current[key];
    }, data);
    parent[last] = value;
  }

  return {
    data,
    ref(path = '') {
      return {
        key: undefined,
        push() {
          return { key: 'ORDER00000000000001' };
        },
        async get() {
          return { val: () => getAt(path) };
        },
        async set(value) {
          setAt(path, value);
        },
        async update(updates) {
          for (const [updatePath, value] of Object.entries(updates)) {
            setAt(updatePath, value);
          }
        },
        async transaction(update) {
          const current = getAt(path);
          const next = update(current);
          if (next === undefined) {
            return { committed: false, snapshot: { val: () => current } };
          }
          setAt(path, next);
          return { committed: true, snapshot: { val: () => next } };
        },
      };
    },
  };
}

test('createOrder calcula el importe del catálogo e ignora el total del cliente', async () => {
  const database = createMemoryDatabase({
    products: {
      torta: { name: 'Torta', available: true, priceCents: 5000 },
    },
  });
  const createOrder = createCreateOrderHandler({
    database,
    serverTimestamp: () => 123456,
  });

  const result = await createOrder({
    auth: { uid: 'user-1' },
    data: {
      lines: [
        {
          productId: 'torta',
          quantity: 2,
          priceCents: 1,
          unitPriceCents: 1,
          totalCents: 1,
        },
      ],
      totalCents: 1,
      pickupMode: 'take_away',
    },
  });

  const order = database.data.orders[result.orderId];
  assert.equal(order.totalCents, 10000);
  assert.equal(order.lines[0].unitPriceCents, 5000);
  assert.equal(order.createdAt, 123456);
  assert.equal(order.status, 'pendiente_pago');
  assert.equal(order.pickupMode, 'take_away');
  assert.deepEqual(
    database.data.ordersByUser['user-1'][result.orderId],
    order,
  );
  assert.deepEqual(database.data.staffQueue[result.orderId], {
    orderId: result.orderId,
  });
});

test('updateOrderStatus rechaza a clientes sin claim de personal', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: {
        ownerUid: 'user-1',
        status: 'pagado',
      },
    },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({ database });

  await assert.rejects(
    updateOrderStatus({
      auth: { uid: 'user-1', token: {} },
      data: { orderId: 'ORDER00000000000001', status: 'preparing' },
    }),
    { code: 'permission-denied' },
  );
  assert.equal(database.data.orders.ORDER00000000000001.status, 'pagado');
});

test('updateOrderStatus rechaza cancelar pedidos pagados y retroceder entregados', async () => {
  const database = createMemoryDatabase({
    orders: {
      PAID0000000000000001: {
        ownerUid: 'user-1',
        status: 'paid',
      },
      DELIVERED00000000001: {
        ownerUid: 'user-1',
        status: 'delivered',
      },
    },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({ database });
  const request = (orderId, status) => ({
    auth: { uid: 'staff-1', token: { staff: true } },
    data: { orderId, status },
  });

  await assert.rejects(
    updateOrderStatus(request('PAID0000000000000001', 'cancelled')),
    { code: 'failed-precondition' },
  );
  await assert.rejects(
    updateOrderStatus(request('DELIVERED00000000001', 'ready')),
    { code: 'failed-precondition' },
  );
  assert.equal(database.data.orders.PAID0000000000000001.status, 'paid');
  assert.equal(database.data.orders.DELIVERED00000000001.status, 'delivered');
});

test('updateOrderStatus permite avanzar a personal admin y sincroniza los índices', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: {
        ownerUid: 'user-1',
        status: 'pagado',
        totalCents: 5000,
      },
    },
    ordersByUser: { 'user-1': { ORDER00000000000001: true } },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({ database });

  const result = await updateOrderStatus({
    auth: { uid: 'admin-1', token: { admin: true } },
    data: { orderId: 'ORDER00000000000001', status: 'preparing' },
  });

  assert.equal(result.order.status, 'preparing');
  assert.equal(database.data.orders.ORDER00000000000001.status, 'preparing');
  assert.equal(
    database.data.ordersByUser['user-1'].ORDER00000000000001.status,
    'preparing',
  );
  assert.deepEqual(database.data.staffQueue.ORDER00000000000001, {
    orderId: 'ORDER00000000000001',
  });
});

test('createPaymentIntent toma el monto guardado y usa idempotencia por pedido', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: {
        ownerUid: 'user-1',
        status: 'pendiente_pago',
        totalCents: 7600,
      },
    },
  });
  const stripeCalls = [];
  const stripe = {
    paymentIntents: {
      async create(params, options) {
        stripeCalls.push({ params, options });
        return {
          id: 'pi-simulado',
          client_secret: 'secreto-simulado-para-pruebas',
        };
      },
    },
  };
  const createPaymentIntent = createCreatePaymentIntentHandler({
    database,
    stripe,
  });

  const result = await createPaymentIntent({
    auth: { uid: 'user-1' },
    data: { orderId: 'ORDER00000000000001', amount: 1 },
  });

  assert.equal(stripeCalls[0].params.amount, 7600);
  assert.equal(stripeCalls[0].params.currency, 'mxn');
  assert.deepEqual(
    stripeCalls[0].params.automatic_payment_methods,
    { enabled: true },
  );
  assert.deepEqual(stripeCalls[0].params.metadata, {
    orderId: 'ORDER00000000000001',
  });
  assert.equal(
    stripeCalls[0].options.idempotencyKey,
    'order-ORDER00000000000001',
  );
  assert.equal(result.clientSecret, 'secreto-simulado-para-pruebas');
  assert.equal(
    database.data.payments.ORDER00000000000001.paymentIntentId,
    'pi-simulado',
  );
});

test('stripeWebhook valida el cuerpo original e idempotentemente marca el pedido pagado', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: {
        ownerUid: 'user-1',
        status: 'pendiente_pago',
        totalCents: 7600,
      },
    },
    payments: {
      ORDER00000000000001: {
        paymentIntentId: 'pi-simulado',
        status: 'requires_payment',
      },
    },
  });
  const rawBody = Buffer.from('cuerpo original');
  const event = {
    type: 'payment_intent.succeeded',
    data: {
      object: {
        id: 'pi-simulado',
        metadata: { orderId: 'ORDER00000000000001' },
      },
    },
  };
  const stripe = {
    webhooks: {
      constructEvent(body, signature, secret) {
        assert.equal(body, rawBody);
        assert.equal(signature, 'firma-simulada');
        assert.equal(secret, 'secreto-de-webhook-simulado');
        return event;
      },
    },
  };
  const webhook = createStripeWebhookHandler({
    database,
    stripe,
    webhookSecret: 'secreto-de-webhook-simulado',
  });
  const response = {
    statusCode: undefined,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    send(body) {
      this.body = body;
    },
  };
  const request = {
    rawBody,
    get: () => 'firma-simulada',
  };

  await webhook(request, response);
  await webhook(request, response);

  assert.equal(database.data.orders.ORDER00000000000001.status, 'pagado');
  assert.equal(
    database.data.ordersByUser['user-1'].ORDER00000000000001.status,
    'pagado',
  );
  assert.deepEqual(database.data.staffQueue.ORDER00000000000001, {
    orderId: 'ORDER00000000000001',
  });
  assert.equal(
    database.data.payments.ORDER00000000000001.status,
    'succeeded',
  );
  assert.equal(response.statusCode, 200);
});

test('stripeWebhook conserva pendiente de pago y registra el rechazo', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: {
        ownerUid: 'user-1',
        status: 'pendiente_pago',
        totalCents: 7600,
      },
    },
    payments: {
      ORDER00000000000001: {
        paymentIntentId: 'pi-simulado',
        status: 'requires_payment',
      },
    },
  });
  const stripe = {
    webhooks: {
      constructEvent() {
        return {
          type: 'payment_intent.payment_failed',
          data: {
            object: {
              id: 'pi-simulado',
              metadata: { orderId: 'ORDER00000000000001' },
              last_payment_error: { message: 'Fondos insuficientes.' },
            },
          },
        };
      },
    },
  };
  const webhook = createStripeWebhookHandler({
    database,
    stripe,
    webhookSecret: 'secreto-de-webhook-simulado',
  });
  const response = {
    status(code) {
      this.statusCode = code;
      return this;
    },
    send(body) {
      this.body = body;
    },
  };

  await webhook(
    {
      rawBody: Buffer.from('cuerpo original'),
      get: () => 'firma-simulada',
    },
    response,
  );

  assert.equal(
    database.data.orders.ORDER00000000000001.status,
    'pendiente_pago',
  );
  assert.equal(
    database.data.orders.ORDER00000000000001.paymentFailureReason,
    'Fondos insuficientes.',
  );
  assert.equal(
    database.data.payments.ORDER00000000000001.failureReason,
    'Fondos insuficientes.',
  );
});
