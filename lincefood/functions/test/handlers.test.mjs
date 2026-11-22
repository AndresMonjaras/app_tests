import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createCreateOrderHandler,
  createCreatePaymentIntentHandler,
  createStripeWebhookHandler,
} from '../src/handlers.mjs';
import { createUpdateOrderStatusHandler } from '../src/orders/update_order_status_handler.mjs';
import { createCancelOrderHandler } from '../src/orders/cancel_order_handler.mjs';
import { createResolveOrderIncidentHandler } from '../src/orders/resolve_order_incident_handler.mjs';

function createMemoryDatabase(initial = {}) {
  const data = structuredClone(initial);
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
