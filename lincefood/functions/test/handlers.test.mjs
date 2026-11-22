import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createCreateOrderHandler,
  createCreatePaymentIntentHandler,
  createStripeWebhookHandler,
} from '../src/handlers.mjs';
import { createUpdateOrderStatusHandler } from '../src/orders/update_order_status_handler.mjs';
import { createCancelOrderHandler } from '../src/orders/cancel_order_handler.mjs';
import { createRejectOrderHandler } from '../src/orders/reject_order_handler.mjs';
import { createResolveOrderIncidentHandler } from '../src/orders/resolve_order_incident_handler.mjs';

function createMemoryDatabase(initial = {}, { coldPaths = [], beforeUpdate } = {}) {
  const data = structuredClone(initial);
  const coldTransactions = new Set(coldPaths);
  let pushCount = 0;

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
          pushCount += 1;
          return { key: 'PUSH' + String(pushCount).padStart(16, '0') };
        },
        async get() {
          return { val: () => getAt(path) };
        },
        async set(value) {
          setAt(path, value);
        },
        async update(updates) {
          if (beforeUpdate) await beforeUpdate(updates);
          for (const [updatePath, value] of Object.entries(updates)) {
            setAt(updatePath, value);
          }
        },
        async transaction(update) {
          if (coldTransactions.delete(path) && update(null) === undefined) {
            return { committed: false, snapshot: { val: () => null } };
          }
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
  // Un pedido sin pagar no debe llegar a la cola de cocina.
  assert.equal(database.data.staffQueue?.[result.orderId], undefined);
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

test('updateOrderStatus no entrega un pedido listo sin QR', async () => {
  const database = createMemoryDatabase({
    orders: {
      READY0000000000000001: {
        ownerUid: 'user-1',
        status: 'ready',
      },
    },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({ database });

  await assert.rejects(
    updateOrderStatus({
      auth: { uid: 'staff-1', token: { staff: true } },
      data: { orderId: 'READY0000000000000001', status: 'delivered' },
    }),
    { code: 'invalid-argument' },
  );
  assert.equal(database.data.orders.READY0000000000000001.status, 'ready');
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
  const updateOrderStatus = createUpdateOrderStatusHandler({
    database,
    now: () => 1000,
  });

  const result = await updateOrderStatus({
    auth: { uid: 'admin-1', token: { admin: true } },
    data: { orderId: 'ORDER00000000000001', status: 'confirmed' },
  });

  assert.equal(result.order.status, 'confirmed');
  assert.equal(database.data.orders.ORDER00000000000001.status, 'confirmed');
  assert.equal(
    database.data.ordersByUser['user-1'].ORDER00000000000001.status,
    'confirmed',
  );
  assert.deepEqual(database.data.staffQueue.ORDER00000000000001, {
    orderId: 'ORDER00000000000001',
  });
});

test('updateOrderStatus guarda fecha, operador y evento al confirmar', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: { ownerUid: 'user-1', status: 'pagado' },
    },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({
    database,
    now: () => 5000,
  });

  await updateOrderStatus({
    auth: { uid: 'staff-1', token: { staff: true } },
    data: { orderId: 'ORDER00000000000001', status: 'confirmed' },
  });

  const order = database.data.orders.ORDER00000000000001;
  assert.equal(order.confirmedAt, 5000);
  assert.equal(order.confirmedBy, 'staff-1');
  assert.equal(
    database.data.ordersByUser['user-1'].ORDER00000000000001.confirmedBy,
    undefined,
  );
  const events = Object.values(database.data.orderEvents.ORDER00000000000001);
  assert.equal(events.length, 1);
  assert.deepEqual(events[0], {
    type: 'status_changed',
    from: 'paid',
    to: 'confirmed',
    actorUid: 'staff-1',
    actorRole: 'staff',
    at: 5000,
  });
});

test('updateOrderStatus recorre el flujo completo paso a paso con auditoría', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: { ownerUid: 'user-1', status: 'paid' },
    },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({
    database,
    now: () => 7000,
  });
  const staff = { uid: 'staff-1', token: { staff: true } };

  for (const status of ['confirmed', 'preparing', 'ready']) {
    await updateOrderStatus({
      auth: staff,
      data: { orderId: 'ORDER00000000000001', status },
    });
  }

  const order = database.data.orders.ORDER00000000000001;
  assert.equal(order.status, 'ready');
  assert.equal(order.confirmedBy, 'staff-1');
  assert.equal(order.preparingAt, 7000);
  assert.equal(order.readyAt, 7000);
  assert.equal(order.deliveredAt, undefined);
  assert.equal(
    Object.values(database.data.orderEvents.ORDER00000000000001).length,
    3,
  );
});

test('updateOrderStatus rechaza saltar pasos y repetir el estado actual', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: { ownerUid: 'user-1', status: 'paid' },
    },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({ database });
  const staff = { uid: 'staff-1', token: { staff: true } };
  const request = (status) => ({
    auth: staff,
    data: { orderId: 'ORDER00000000000001', status },
  });

  await assert.rejects(updateOrderStatus(request('preparing')), {
    code: 'failed-precondition',
  });
  await assert.rejects(updateOrderStatus(request('ready')), {
    code: 'failed-precondition',
  });
  await assert.rejects(updateOrderStatus(request('paid')), {
    code: 'permission-denied',
  });
  await assert.rejects(updateOrderStatus(request('payment_pending')), {
    code: 'permission-denied',
  });

  assert.equal(database.data.orders.ORDER00000000000001.status, 'paid');
  assert.equal(database.data.orderEvents, undefined);
});

test('updateOrderStatus no acepta cancelar aunque el pedido esté pendiente de pago', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: { ownerUid: 'user-1', status: 'pendiente_pago' },
      ORDER00000000000002: { ownerUid: 'user-1', status: 'confirmed' },
    },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({ database });
  const admin = { uid: 'admin-1', token: { admin: true } };

  for (const orderId of ['ORDER00000000000001', 'ORDER00000000000002']) {
    await assert.rejects(
      updateOrderStatus({ auth: admin, data: { orderId, status: 'cancelled' } }),
      { code: 'failed-precondition' },
    );
  }
  assert.equal(database.data.orders.ORDER00000000000002.status, 'confirmed');
});

test('updateOrderStatus impide que el personal marque incidencias', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: { ownerUid: 'user-1', status: 'confirmed' },
    },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({ database });

  await assert.rejects(
    updateOrderStatus({
      auth: { uid: 'staff-1', token: { staff: true } },
      data: {
        orderId: 'ORDER00000000000001',
        status: 'incident',
        reason: 'Agotado',
      },
    }),
    { code: 'permission-denied' },
  );
  assert.equal(database.data.orders.ORDER00000000000001.status, 'confirmed');
});

test('updateOrderStatus permite a un admin pasar a incidencia con motivo', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: { ownerUid: 'user-1', status: 'ready' },
      ORDER00000000000002: { ownerUid: 'user-1', status: 'pendiente_pago' },
    },
  });
  const updateOrderStatus = createUpdateOrderStatusHandler({
    database,
    now: () => 9000,
  });
  const admin = { uid: 'admin-1', token: { admin: true } };

  await assert.rejects(
    updateOrderStatus({
      auth: admin,
      data: { orderId: 'ORDER00000000000001', status: 'incident' },
    }),
    { code: 'invalid-argument' },
  );
  await assert.rejects(
    updateOrderStatus({
      auth: admin,
      data: { orderId: 'ORDER00000000000002', status: 'incident', reason: 'Cobro' },
    }),
    { code: 'failed-precondition' },
  );

  await updateOrderStatus({
    auth: admin,
    data: {
      orderId: 'ORDER00000000000001',
      status: 'incident',
      reason: 'Cobro inconsistente',
    },
  });

  const order = database.data.orders.ORDER00000000000001;
  assert.equal(order.status, 'incident');
  assert.equal(order.incidentBy, 'admin-1');
  assert.equal(order.incidentAt, 9000);
  assert.equal(database.data.staffQueue.ORDER00000000000001.orderId, 'ORDER00000000000001');
  const [event] = Object.values(database.data.orderEvents.ORDER00000000000001);
  assert.equal(event.type, 'incident_reported');
  assert.equal(event.reason, 'Cobro inconsistente');
  assert.equal(event.actorRole, 'admin');
});

test('resolveOrderIncident solo lo puede cerrar un administrador', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: {
        ownerUid: 'user-1',
        status: 'incident',
        incidentBy: 'admin-1',
      },
    },
    staffQueue: { ORDER00000000000001: { orderId: 'ORDER00000000000001' } },
  });
  const resolveOrderIncident = createResolveOrderIncidentHandler({
    database,
    now: () => 11000,
  });
  const request = (auth) => ({
    auth,
    data: { orderId: 'ORDER00000000000001', resolution: 'Reembolso manual' },
  });

  await assert.rejects(
    resolveOrderIncident(request({ uid: 'staff-1', token: { staff: true } })),
    { code: 'permission-denied' },
  );
  await assert.rejects(
    resolveOrderIncident(request({ uid: 'user-1', token: {} })),
    { code: 'permission-denied' },
  );
  assert.equal(database.data.orders.ORDER00000000000001.incidentResolvedAt, undefined);

  await resolveOrderIncident(request({ uid: 'admin-1', token: { admin: true } }));

  const order = database.data.orders.ORDER00000000000001;
  assert.equal(order.incidentResolvedAt, 11000);
  assert.equal(order.incidentResolvedBy, 'admin-1');
  assert.equal(database.data.staffQueue.ORDER00000000000001, null);
  const events = Object.values(database.data.orderEvents.ORDER00000000000001);
  assert.equal(events.at(-1).type, 'incident_resolved');
  assert.equal(events.at(-1).note, 'Reembolso manual');
});

test('resolveOrderIncident rechaza resolver dos veces o un pedido sin incidencia', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: {
        ownerUid: 'user-1',
        status: 'incident',
        incidentResolvedAt: 1,
      },
      ORDER00000000000002: { ownerUid: 'user-1', status: 'ready' },
    },
  });
  const resolveOrderIncident = createResolveOrderIncidentHandler({ database });
  const admin = { uid: 'admin-1', token: { admin: true } };

  await assert.rejects(
    resolveOrderIncident({
      auth: admin,
      data: { orderId: 'ORDER00000000000001', resolution: 'Listo' },
    }),
    { code: 'failed-precondition' },
  );
  await assert.rejects(
    resolveOrderIncident({
      auth: admin,
      data: { orderId: 'ORDER00000000000002', resolution: 'Listo' },
    }),
    { code: 'failed-precondition' },
  );
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
          livemode: false,
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
    uid: 'user-1',
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

test('stripeWebhook confirma el pedido desde una caché fría y admite duplicados', async () => {
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
  }, { coldPaths: ['orders/ORDER00000000000001'] });
  const rawBody = Buffer.from('cuerpo original');
  const event = {
    type: 'payment_intent.succeeded',
    livemode: false,
    data: {
      object: {
        id: 'pi-simulado',
        amount_received: 7600,
        currency: 'mxn',
        metadata: { orderId: 'ORDER00000000000001', uid: 'user-1' },
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

  assert.equal(database.data.orders.ORDER00000000000001.status, 'paid');
  assert.equal(
    database.data.ordersByUser['user-1'].ORDER00000000000001.status,
    'paid',
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

test('createPaymentIntent no pisa un pago que el webhook confirmó durante un reintento', async () => {
  const orderId = 'ORDER00000000000001';
  const paymentPath = 'payments/' + orderId;
  const database = createMemoryDatabase({
    orders: {
      [orderId]: { ownerUid: 'user-1', status: 'pendiente_pago', totalCents: 7600 },
    },
  }, { coldPaths: [paymentPath] });
  const payment = { paymentIntentId: 'pi-simulado', status: 'succeeded' };
  const createPaymentIntent = createCreatePaymentIntentHandler({
    database,
    stripe: {
      paymentIntents: {
        async create() {
          await database.ref(paymentPath).set(payment);
          return {
            id: payment.paymentIntentId,
            client_secret: 'secreto-simulado-para-pruebas',
            livemode: false,
          };
        },
      },
    },
  });

  await createPaymentIntent({ auth: { uid: 'user-1' }, data: { orderId } });

  assert.deepEqual(database.data.payments[orderId], payment);
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
          livemode: false,
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

function createWebhookHarness(database, event) {
  const stripe = {
    webhooks: {
      constructEvent() {
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
    rawBody: Buffer.from('cuerpo original'),
    get: () => 'firma-simulada',
  };
  return { webhook, request, response };
}

function pendingOrderDatabase() {
  return createMemoryDatabase({
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
}

test('un pago cancelado no envía el pedido a cocina y permite reintentar', async () => {
  const database = pendingOrderDatabase();
  const { webhook, request, response } = createWebhookHarness(database, {
    type: 'payment_intent.canceled',
    livemode: false,
    data: {
      object: {
        id: 'pi-simulado',
        metadata: { orderId: 'ORDER00000000000001' },
      },
    },
  });

  await webhook(request, response);

  assert.equal(
    database.data.orders.ORDER00000000000001.status,
    'pendiente_pago',
  );
  assert.equal(database.data.staffQueue?.ORDER00000000000001, undefined);
  assert.equal(
    database.data.payments.ORDER00000000000001.status,
    'failed',
  );
});

test('un cobro con importe distinto al del pedido no lo marca pagado', async () => {
  const database = pendingOrderDatabase();
  const { webhook, request, response } = createWebhookHarness(database, {
    type: 'payment_intent.succeeded',
    livemode: false,
    data: {
      object: {
        id: 'pi-simulado',
        amount_received: 100,
        currency: 'mxn',
        metadata: { orderId: 'ORDER00000000000001', uid: 'user-1' },
      },
    },
  });

  await webhook(request, response);

  assert.equal(
    database.data.orders.ORDER00000000000001.status,
    'pendiente_pago',
  );
  assert.equal(database.data.staffQueue?.ORDER00000000000001, undefined);
  assert.equal(response.statusCode, 200);
});

test('un evento de modo producción se rechaza sin tocar el pedido', async () => {
  const database = pendingOrderDatabase();
  const { webhook, request, response } = createWebhookHarness(database, {
    type: 'payment_intent.succeeded',
    livemode: true,
    data: {
      object: {
        id: 'pi-simulado',
        amount_received: 7600,
        currency: 'mxn',
        metadata: { orderId: 'ORDER00000000000001', uid: 'user-1' },
      },
    },
  });

  await webhook(request, response);

  assert.equal(response.statusCode, 400);
  assert.equal(
    database.data.orders.ORDER00000000000001.status,
    'pendiente_pago',
  );
});

function fakeStripe({ fail = false } = {}) {
  const calls = [];
  return {
    calls,
    refunds: {
      async create(params, options) {
        calls.push({ params, options });
        if (fail) throw new Error('stripe caído');
        return { id: 're_1' };
      },
    },
  };
}

test('cancelOrder cancela un pedido pagado, reembolsa y lo saca de la cola', async () => {
  const database = createMemoryDatabase({
    orders: {
      ORDER00000000000001: { ownerUid: 'user-1', status: 'paid', totalCents: 5000 },
    },
    payments: {
      ORDER00000000000001: { status: 'succeeded', paymentIntentId: 'pi_1' },
    },
    staffQueue: { ORDER00000000000001: { orderId: 'ORDER00000000000001' } },
    ordersByUser: { 'user-1': { ORDER00000000000001: true } },
  });
  const stripe = fakeStripe();
  const cancelOrder = createCancelOrderHandler({ database, stripe, now: () => 9000 });

  const result = await cancelOrder({
    auth: { uid: 'user-1', token: {} },
    data: { orderId: 'ORDER00000000000001' },
  });

  assert.deepEqual(result, {
    orderId: 'ORDER00000000000001',
    status: 'cancelled',
    refundStatus: 'requested',
  });
  const order = database.data.orders.ORDER00000000000001;
  assert.equal(order.status, 'cancelled');
  assert.equal(order.isCancelled, true);
  assert.equal(order.cancelledBy, 'user-1');
  assert.equal(database.data.staffQueue.ORDER00000000000001, null);
  assert.equal(database.data.payments.ORDER00000000000001.refundStatus, 'requested');
  assert.equal(stripe.calls.length, 1);
  assert.equal(stripe.calls[0].params.payment_intent, 'pi_1');
  assert.equal(stripe.calls[0].options.idempotencyKey, 'refund-ORDER00000000000001');
});

test('cancelOrder rechaza cancelar cuando el pedido ya está en cocina', async () => {
  const database = createMemoryDatabase({
    orders: { ORDER00000000000001: { ownerUid: 'user-1', status: 'preparing' } },
  });
  const cancelOrder = createCancelOrderHandler({ database, stripe: fakeStripe() });

  await assert.rejects(
    cancelOrder({
      auth: { uid: 'user-1', token: {} },
      data: { orderId: 'ORDER00000000000001' },
    }),
    { code: 'failed-precondition' },
  );
  assert.equal(database.data.orders.ORDER00000000000001.status, 'preparing');
});

test('cancelOrder no permite cancelar el pedido de otro cliente', async () => {
  const database = createMemoryDatabase({
    orders: { ORDER00000000000001: { ownerUid: 'user-1', status: 'paid' } },
  });
  const cancelOrder = createCancelOrderHandler({ database, stripe: fakeStripe() });

  await assert.rejects(
    cancelOrder({
      auth: { uid: 'user-2', token: {} },
      data: { orderId: 'ORDER00000000000001' },
    }),
    { code: 'permission-denied' },
  );
  assert.equal(database.data.orders.ORDER00000000000001.status, 'paid');
});

test('cancelOrder deja el reembolso pendiente si Stripe falla', async () => {
  const database = createMemoryDatabase({
    orders: { ORDER00000000000001: { ownerUid: 'user-1', status: 'confirmed' } },
    payments: { ORDER00000000000001: { status: 'succeeded', paymentIntentId: 'pi_1' } },
  });
  const cancelOrder = createCancelOrderHandler({
    database,
    stripe: fakeStripe({ fail: true }),
  });

  await assert.rejects(
    cancelOrder({
      auth: { uid: 'user-1', token: {} },
      data: { orderId: 'ORDER00000000000001' },
    }),
    { code: 'internal' },
  );
  assert.equal(database.data.orders.ORDER00000000000001.status, 'cancelled');
  assert.equal(database.data.payments.ORDER00000000000001.refundStatus, 'pending');
});

test('cancelOrder no llama a Stripe si el pago no se completó', async () => {
  const database = createMemoryDatabase({
    orders: { ORDER00000000000001: { ownerUid: 'user-1', status: 'paid' } },
    payments: { ORDER00000000000001: { status: 'pending' } },
  });
  const stripe = fakeStripe();
  const cancelOrder = createCancelOrderHandler({ database, stripe });

  const result = await cancelOrder({
    auth: { uid: 'user-1', token: {} },
    data: { orderId: 'ORDER00000000000001' },
  });

  assert.equal(result.refundStatus, null);
  assert.equal(stripe.calls.length, 0);
});

test('cancelOrder cancela aunque la primera pasada de la transacción llegue vacía', async () => {
  const database = createMemoryDatabase(
    {
      orders: { ORDER00000000000001: { ownerUid: 'user-1', status: 'paid' } },
      payments: { ORDER00000000000001: { status: 'succeeded', paymentIntentId: 'pi_1' } },
    },
    { coldPaths: ['orders/ORDER00000000000001'] },
  );
  const cancelOrder = createCancelOrderHandler({ database, stripe: fakeStripe() });

  const result = await cancelOrder({
    auth: { uid: 'user-1', token: {} },
    data: { orderId: 'ORDER00000000000001' },
  });

  assert.equal(result.status, 'cancelled');
  assert.equal(database.data.orders.ORDER00000000000001.status, 'cancelled');
});

test('cancelOrder responde no encontrado solo si el pedido no existe', async () => {
  const database = createMemoryDatabase({ orders: {} });
  const cancelOrder = createCancelOrderHandler({ database, stripe: fakeStripe() });

  await assert.rejects(
    cancelOrder({
      auth: { uid: 'user-1', token: {} },
      data: { orderId: 'ORDER00000000000009' },
    }),
    { code: 'not-found' },
  );
});

test('cancelOrder cancela un pedido con pago pendiente y anula el intento en Stripe', async () => {
  const database = createMemoryDatabase({
    orders: { ORDER00000000000001: { ownerUid: 'user-1', status: 'pendiente_pago' } },
    payments: {
      ORDER00000000000001: { status: 'requires_payment', paymentIntentId: 'pi_9' },
    },
  });
  const cancelledIntents = [];
  const stripe = {
    ...fakeStripe(),
    paymentIntents: {
      async retrieve(id) {
        return { id, status: 'requires_payment_method' };
      },
      async cancel(id) {
        cancelledIntents.push(id);
        return { id, status: 'canceled' };
      },
    },
  };
  const cancelOrder = createCancelOrderHandler({ database, stripe });

  const result = await cancelOrder({
    auth: { uid: 'user-1', token: {} },
    data: { orderId: 'ORDER00000000000001' },
  });

  assert.equal(result.refundStatus, null);
  assert.deepEqual(cancelledIntents, ['pi_9']);
  assert.equal(database.data.orders.ORDER00000000000001.status, 'cancelled');
  assert.equal(database.data.payments.ORDER00000000000001.status, 'canceled');
  assert.equal(stripe.calls.length, 0);
});

test('updateOrderStatus avanza aunque la primera pasada de la transacción llegue vacía', async () => {
  const database = createMemoryDatabase(
    { orders: { ORDER00000000000001: { ownerUid: 'user-1', status: 'paid' } } },
    { coldPaths: ['orders/ORDER00000000000001'] },
  );
  const updateOrderStatus = createUpdateOrderStatusHandler({ database, now: () => 100 });

  await updateOrderStatus({
    auth: { uid: 'staff-1', token: { staff: true } },
    data: { orderId: 'ORDER00000000000001', status: 'confirmed' },
  });

  assert.equal(database.data.orders.ORDER00000000000001.status, 'confirmed');
});

test('cancelOrder reembolsa si Stripe ya cobró aunque el webhook no lo registrara', async () => {
  const database = createMemoryDatabase({
    orders: { ORDER00000000000001: { ownerUid: 'user-1', status: 'pendiente_pago' } },
    payments: {
      ORDER00000000000001: { status: 'requires_payment', paymentIntentId: 'pi_7' },
    },
  });
  const stripe = {
    ...fakeStripe(),
    paymentIntents: {
      async retrieve(id) {
        return { id, status: 'succeeded' };
      },
      async cancel() {
        throw new Error('no debe anular un cobro hecho');
      },
    },
  };
  const cancelOrder = createCancelOrderHandler({ database, stripe });

  const result = await cancelOrder({
    auth: { uid: 'user-1', token: {} },
    data: { orderId: 'ORDER00000000000001' },
  });

  assert.equal(result.refundStatus, 'requested');
  assert.equal(stripe.calls[0].params.payment_intent, 'pi_7');
});

const rejectionOrderId = 'pedido-1';
const rejectionOwner = 'estudiante-1';
const rejectionNote = 'Se agotó el platillo solicitado.';

function setupRejection({
  status = 'paid',
  paymentStatus = 'succeeded',
  stripe = fakeStripe(),
  databaseOptions,
} = {}) {
  const order = { ownerUid: rejectionOwner, status, totalCents: 5000 };
  const database = createMemoryDatabase({
    orders: { [rejectionOrderId]: order },
    payments: { [rejectionOrderId]: { status: paymentStatus, paymentIntentId: 'pi_1' } },
    ordersByUser: { [rejectionOwner]: { [rejectionOrderId]: { ...order } } },
    staffQueue: { [rejectionOrderId]: { orderId: rejectionOrderId } },
  }, databaseOptions);
  let clock = 1000;
  const reject = createRejectOrderHandler({ database, stripe, now: () => clock++ });
  const request = {
    auth: { uid: 'staff-1', token: { staff: true } },
    data: { orderId: rejectionOrderId, reason: rejectionNote },
  };
  return { database, stripe, reject, request };
}

test('rejectOrder exige autenticación y claim staff o admin', async () => {
  const { database, stripe, reject, request } = setupRejection();
  const original = structuredClone(database.data);
  await assert.rejects(reject({ data: request.data }), { code: 'unauthenticated' });
  await assert.rejects(
    reject({ ...request, auth: { uid: rejectionOwner, token: { staff: 'true' } } }),
    { code: 'permission-denied' },
  );
  assert.deepEqual(database.data, original);
  assert.deepEqual(stripe.calls, []);
});

test('rejectOrder valida la nota recortada por caracteres visibles', async () => {
  const letter = 'a\u0301';
  const { database, stripe, reject, request } = setupRejection();
  const original = structuredClone(database.data);
  for (const reason of [undefined, 42, '   ', ' 1234 ', letter.repeat(4), letter.repeat(201)]) {
    await assert.rejects(reject({ ...request, data: { ...request.data, reason } }), {
      code: 'invalid-argument',
    });
  }
  assert.deepEqual(database.data, original);
  assert.deepEqual(stripe.calls, []);

  for (const size of [5, 200]) {
    const scenario = setupRejection();
    const reason = letter.repeat(size);
    await scenario.reject({
      ...scenario.request,
      data: { orderId: rejectionOrderId, reason: '  ' + reason + '  ' },
    });
    assert.equal(scenario.database.data.orders[rejectionOrderId].rejectionReason, reason);
  }
});

test('rejectOrder solo admite pagado o confirmado y conserva los demás estados', async () => {
  for (const status of [
    'payment_pending', 'preparing', 'en preparación', 'ready', 'delivered',
    'incident', 'cancelled', 'rejected', 'rechazado', 'desconocido',
  ]) {
    const { database, stripe, reject, request } = setupRejection({ status });
    const original = structuredClone(database.data);
    await assert.rejects(reject(request), { code: 'failed-precondition' }, status);
    assert.deepEqual(database.data, original, status);
    assert.deepEqual(stripe.calls, [], status);
  }
});

test('rejectOrder guarda la auditoría, el ticket y el aviso de diez minutos desde caché fría', async () => {
  for (const [status, previous, role] of [
    ['pagado', 'paid', 'staff'],
    ['confirmado', 'confirmed', 'admin'],
  ]) {
    const { database, stripe, reject, request } = setupRejection({
      status, databaseOptions: { coldPaths: ['orders/' + rejectionOrderId] },
    });
    const actorUid = role + '-1';
    const auth = { uid: actorUid, token: { [role]: true } };
    const result = await reject({ ...request, auth });
    const { orders, ordersByUser, orderEvents, staffQueue, rejectionNotices } = database.data;
    const order = orders[rejectionOrderId];
    assert.equal(order.status, 'rejected');
    assert.equal(order.rejectionReason, rejectionNote);
    assert.equal(order.rejectedBy, actorUid);
    assert.equal(order.rejectedAt, 1000);
    assert.equal(result.status, 'rejected');
    assert.deepEqual(ordersByUser[rejectionOwner][rejectionOrderId], {
      ownerUid: rejectionOwner, status: 'rejected', totalCents: 5000,
      rejectionReason: rejectionNote, rejectedAt: 1000,
    });
    assert.deepEqual(Object.values(orderEvents[rejectionOrderId]), [{
      type: 'order_rejected', from: previous, to: 'rejected', actorUid,
      actorRole: role, reason: rejectionNote, at: 1000,
    }]);
    assert.equal(staffQueue[rejectionOrderId], null);
    assert.deepEqual(rejectionNotices, {
      [rejectionOwner]: {
        [rejectionOrderId]: { rejectedAt: 1000, expiresAt: 601000, rejectionReason: rejectionNote },
      },
    });
    await assert.rejects(reject({ ...request, auth }), { code: 'failed-precondition' });
    assert.equal(Object.keys(orderEvents[rejectionOrderId]).length, 1);
    assert.equal(stripe.calls.length, 1);
  }
});

test('rejectOrder responde no encontrado si el valor real sigue siendo null', async () => {
  const path = 'orders/' + rejectionOrderId;
  const { database, stripe, reject, request } = setupRejection({ databaseOptions: { coldPaths: [path] } });
  await database.ref(path).set(null);
  await assert.rejects(reject(request), { code: 'not-found' });
  assert.equal(database.data.orders[rejectionOrderId], null);
  assert.equal(database.data.rejectionNotices, undefined);
  assert.deepEqual(stripe.calls, []);
});

test('rejectOrder consulta el PaymentIntent y reembolsa un pago aún pendiente en RTDB', async () => {
  const stripe = fakeStripe();
  const retrieved = [];
  stripe.paymentIntents = {
    async retrieve(id) {
      retrieved.push(id);
      return { status: 'succeeded' };
    },
  };
  const { database, reject, request } = setupRejection({ stripe, paymentStatus: 'requires_payment' });
  const result = await reject(request);
  assert.deepEqual(retrieved, ['pi_1']);
  assert.equal(result.refundStatus, 'requested');
  assert.equal(database.data.payments[rejectionOrderId].refundStatus, 'requested');
  assert.deepEqual(stripe.calls, [{
    params: { payment_intent: 'pi_1' },
    options: { idempotencyKey: 'refund-' + rejectionOrderId },
  }]);
});

test('rejectOrder conserva el rechazo y deja el reembolso pendiente ante fallo de Stripe', async () => {
  const { database, reject, request } = setupRejection({ stripe: fakeStripe({ fail: true }) });
  await assert.rejects(reject(request), { code: 'internal', message: /reembolso quedó pendiente/i });
  assert.equal(database.data.payments[rejectionOrderId].refundStatus, 'pending');
  assert.equal(database.data.orders[rejectionOrderId].status, 'rejected');
  assert.equal(database.data.ordersByUser[rejectionOwner][rejectionOrderId].status, 'rejected');
  assert.equal(database.data.staffQueue[rejectionOrderId], null);
  assert.equal(database.data.rejectionNotices[rejectionOwner][rejectionOrderId].rejectionReason, rejectionNote);
});

test('rejectOrder reanuda la misma solicitud tras fallar una escritura antes o después de Stripe', async () => {
  for (const failurePath of [
    'ordersByUser/' + rejectionOwner + '/' + rejectionOrderId,
    'payments/' + rejectionOrderId + '/refundStatus',
  ]) {
    let fail = true;
    const { database, stripe, reject, request } = setupRejection({
      databaseOptions: {
        beforeUpdate(updates) {
          if (fail && failurePath in updates) {
            fail = false;
            throw new Error('RTDB no disponible');
          }
        },
      },
    });
    await assert.rejects(reject(request), /RTDB no disponible/);
    await assert.rejects(reject({
      ...request, data: { ...request.data, reason: 'Un motivo diferente.' },
    }), { code: 'failed-precondition' });
    const originalTime = database.data.orders[rejectionOrderId].rejectedAt;
    const result = await reject(request);
    assert.equal(result.refundStatus, 'requested');
    assert.equal(database.data.orders[rejectionOrderId].rejectedAt, originalTime);
    assert.equal(database.data.ordersByUser[rejectionOwner][rejectionOrderId].status, 'rejected');
    assert.equal(database.data.rejectionNotices[rejectionOwner][rejectionOrderId].expiresAt, originalTime + 600000);
    assert.equal(Object.keys(database.data.orderEvents[rejectionOrderId]).length, 1);
    assert.ok(stripe.calls.length > 0);
    assert.deepEqual(new Set(stripe.calls.map((call) => call.options.idempotencyKey)),
      new Set(['refund-' + rejectionOrderId]));
  }
});

test('una confirmación que publica sus índices tarde no recupera el pedido rechazado', async () => {
  const ticketPath = 'ordersByUser/' + rejectionOwner + '/' + rejectionOrderId;
  const { database, reject, request } = setupRejection({
    databaseOptions: {
      async beforeUpdate(updates) {
        if (updates[ticketPath]?.status === 'confirmed') await reject(request);
      },
    },
  });
  const confirm = createUpdateOrderStatusHandler({ database });
  await confirm({
    auth: request.auth,
    data: { orderId: rejectionOrderId, status: 'confirmed' },
  });

  assert.equal(database.data.orders[rejectionOrderId].status, 'rejected');
  const ticket = database.data.ordersByUser[rejectionOwner][rejectionOrderId];
  assert.equal(ticket.status, 'rejected');
  assert.equal(ticket.rejectionReason, rejectionNote);
  assert.equal(database.data.staffQueue[rejectionOrderId], null);
  assert.deepEqual(
    Object.values(database.data.orderEvents[rejectionOrderId]).map((event) => event.to).sort(),
    ['confirmed', 'rejected'],
  );
});

test('rechazo durante el webhook reembolsa aunque todavía no exista payments', async () => {
  const stripe = fakeStripe();
  const intentId = 'pi_cobro_validado';
  stripe.paymentIntents = {
    async retrieve(id) {
      assert.equal(id, intentId);
      return { id, status: 'succeeded' };
    },
  };
  const ticketPath = 'ordersByUser/' + rejectionOwner + '/' + rejectionOrderId;
  let rejected;
  const { database, reject, request } = setupRejection({
    status: 'pendiente_pago',
    stripe,
    databaseOptions: {
      async beforeUpdate(updates) {
        if (updates[ticketPath]?.status === 'paid') rejected = await reject(request);
      },
    },
  });
  await database.ref('payments/' + rejectionOrderId).set(null);
  const webhook = createWebhookHarness(database, {
    livemode: false,
    type: 'payment_intent.succeeded',
    data: { object: {
      id: intentId, currency: 'mxn', amount_received: 5000,
      metadata: { orderId: rejectionOrderId, uid: rejectionOwner },
    } },
  });

  await webhook.webhook(webhook.request, webhook.response);

  assert.equal(webhook.response.statusCode, 200);
  assert.equal(rejected.refundStatus, 'requested');
  assert.deepEqual(stripe.calls, [{
    params: { payment_intent: intentId },
    options: { idempotencyKey: 'refund-' + rejectionOrderId },
  }]);
  assert.equal(database.data.payments[rejectionOrderId].status, 'succeeded');
  assert.equal(database.data.payments[rejectionOrderId].refundStatus, 'requested');
  const ticket = database.data.ordersByUser[rejectionOwner][rejectionOrderId];
  assert.equal(ticket.status, 'rejected');
  assert.equal(ticket.paidPaymentIntentId, undefined);
  assert.equal(database.data.staffQueue[rejectionOrderId], null);
});

test('rechazos concurrentes conservan el reembolso solicitado ante un error tardío', async () => {
  const keys = [];
  let secondResult;
  const stripe = {
    refunds: {
      async create(params, options) {
        assert.equal(params.payment_intent, 'pi_1');
        keys.push(options.idempotencyKey);
        if (keys.length === 1) {
          // La segunda llamada termina mientras la primera aún espera a Stripe.
          secondResult = await reject(request);
          throw new Error('La primera llamada perdió la conexión.');
        }
        return { id: 're_unico' };
      },
    },
  };
  const { database, reject, request } = setupRejection({ stripe });
  const firstResult = await reject(request);

  assert.equal(secondResult.refundStatus, 'requested');
  assert.equal(firstResult.refundStatus, 'requested');
  assert.deepEqual(keys, ['refund-' + rejectionOrderId, 'refund-' + rejectionOrderId]);
  assert.equal(database.data.payments[rejectionOrderId].refundStatus, 'requested');
  assert.equal(Object.keys(database.data.orderEvents[rejectionOrderId]).length, 1);
});

test('rechazo antiguo sin referencia de pago queda pendiente y permite reanudarlo', async () => {
  const { database, stripe, reject, request } = setupRejection({ status: 'confirmed' });
  const payment = database.ref('payments/' + rejectionOrderId);
  await payment.set(null);

  await assert.rejects(reject(request), { code: 'internal', message: /reembolso.*pendiente/i });
  assert.equal(stripe.calls.length, 0);
  assert.equal(database.data.payments[rejectionOrderId].refundStatus, 'pending');
  const order = database.data.orders[rejectionOrderId];
  assert.equal(order.status, 'rejected');
  assert.equal(order.rejectionPendingFrom, 'confirmed');
  const rejectedAt = order.rejectedAt;

  await payment.set({
    ...database.data.payments[rejectionOrderId], paymentIntentId: 'pi_antiguo', status: 'succeeded',
  });
  const recovered = await reject(request);
  assert.equal(recovered.refundStatus, 'requested');
  assert.equal(database.data.payments[rejectionOrderId].refundStatus, 'requested');
  assert.equal(database.data.orders[rejectionOrderId].rejectedAt, rejectedAt);
  assert.equal(stripe.calls.length, 1);
  assert.equal(Object.keys(database.data.orderEvents[rejectionOrderId]).length, 1);
});
