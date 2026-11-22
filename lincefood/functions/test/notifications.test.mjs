import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

import { AppError } from '../src/app_error.mjs';
import { loadNotificationCopies } from '../src/notifications/notification_copy.mjs';
import { buildOrderReadyMessage } from '../src/notifications/notification_payloads.mjs';
import { createOrderStatusNotificationHandler } from '../src/notifications/order_status_notification_handler.mjs';
import { sendNotificationToUser } from '../src/notifications/notification_sender.mjs';
import { createSendRecommendationHandler } from '../src/notifications/send_recommendation_handler.mjs';
import { createSendTopicNotificationHandler } from '../src/notifications/send_topic_notification_handler.mjs';

const sourceSeedUrl = new URL(
  '../../firebase/seeds/notificaciones.seed.json',
  import.meta.url,
);

test('el seed incluido en Functions coincide con el seed de la app', async () => {
  const sourceSeed = JSON.parse(await readFile(sourceSeedUrl, 'utf8'));
  assert.deepEqual(await loadNotificationCopies(), sourceSeed);
});

test('el payload de pedido listo usa texto genérico y no contiene datos del pedido', async () => {
  const copies = await loadNotificationCopies();
  assert.deepEqual(buildOrderReadyMessage(copies), {
    notification: {
      title: copies.pedido_listo.titulo,
      body: copies.pedido_listo.cuerpo,
    },
    data: { type: 'pedido_listo' },
    android: {
      priority: 'high',
      notification: { channelId: 'avisos_cafeteria' },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { sound: 'default' } },
    },
  });
});

test('envía a los tokens del usuario y elimina los tokens no registrados', async () => {
  const database = new FakeDatabase({
    'notificationTokens/usuario-1': {
      hashValido: { token: 'token-valido' },
      hashCaducado: { token: 'token-caducado' },
    },
  });
  const sent = [];
  const messaging = {
    async sendEachForMulticast(message) {
      sent.push(message);
      return {
        successCount: 1,
        responses: [
          { success: true },
          {
            success: false,
            error: { code: 'messaging/registration-token-not-registered' },
          },
        ],
      };
    },
  };

  const result = await sendNotificationToUser({
    database,
    messaging,
    uid: 'usuario-1',
    message: { notification: { title: 'Aviso', body: 'Texto' }, data: {} },
  });

  assert.equal(result.successCount, 1);
  assert.deepEqual(sent[0].tokens, ['token-valido', 'token-caducado']);
  assert.deepEqual(database.removed, [
    'notificationTokens/usuario-1/hashCaducado',
  ]);
});

test('el cambio a listo envía el payload genérico con ID técnico y sin datos de compra', async () => {
  const database = new FakeDatabase({
    'orders/pedido-1/ownerUid': 'usuario-1',
    'notificationTokens/usuario-1': {
      hashValido: { token: 'token-valido' },
    },
  });
  const sent = [];
  const handler = createOrderStatusNotificationHandler({
    database,
    messaging: {
      async sendEachForMulticast(message) {
        sent.push(message);
        return { successCount: 1, responses: [{ success: true }] };
      },
    },
    loadCopies: loadNotificationCopies,
  });

  await handler({
    params: { orderId: 'pedido-1' },
    data: {
      before: { val: () => ({ status: 'preparing' }) },
      after: { val: () => ({ status: 'ready', ownerUid: 'usuario-1' }) },
    },
  });

  assert.equal(sent.length, 1);
  assert.deepEqual(sent[0].data, {
    type: 'pedido_listo',
    orderId: 'pedido-1',
  });
  assert.equal(JSON.stringify(sent[0]).includes('folio'), false);
  assert.equal(JSON.stringify(sent[0]).includes('importe'), false);
  const inboxItems = Object.entries(database.values).filter(([path]) =>
    path.startsWith('notificationInbox/usuario-1/'),
  );
  assert.equal(inboxItems.length, 1);
  assert.equal(inboxItems[0][1].type, 'pedido_listo');
  assert.equal(inboxItems[0][1].isRead, false);
});

test('pedido pagado creado o actualizado solo dispara pedido registrado', async () => {
  const { handler, sent, database } = createOrderHandler();

  await handler(orderEvent(null, { status: 'pagado', ownerUid: 'usuario-1' }));
  await handler(orderEvent(
    { status: 'pendiente_pago', ownerUid: 'usuario-1' },
    { status: 'pagado', ownerUid: 'usuario-1' },
  ));
  await handler(orderEvent(
    { status: 'pagado', ownerUid: 'usuario-1' },
    { status: 'pagado', ownerUid: 'usuario-1', updatedAt: 3 },
  ));

  assert.deepEqual(sent.map((message) => message.data.type), [
    'pedido_registrado',
  ]);
  assert.equal(
    Object.keys(database.values).filter((path) =>
      path.startsWith('notificationInbox/'),
    ).length,
    1,
  );
});

test('cambio a preparing dispara pedido en cocina', async () => {
  const { handler, sent } = createOrderHandler();
  await handler(orderEvent(
    { status: 'paid', ownerUid: 'usuario-1' },
    { status: 'preparing', ownerUid: 'usuario-1' },
  ));

  assert.equal(sent.length, 1);
  assert.equal(sent[0].data.type, 'pedido_en_cocina');
});

test('el callable rechaza usuarios que no tienen claim admin o staff', async () => {
  const handler = createSendTopicNotificationHandler({
    database: new FakeDatabase({}),
    messaging: { send: async () => assert.fail('No debía enviar el aviso.') },
    loadCopies: loadNotificationCopies,
  });

  await assert.rejects(
    handler({
      auth: { uid: 'usuario-1', token: {} },
      data: { topic: 'cafeteria_menu' },
    }),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
});

test('staff puede enviar texto del seed, pero no texto propio', async () => {
  const sent = [];
  const database = new FakeDatabase({
    notificationPreferences: { 'usuario-1': { cafeteria_menu: true } },
  });
  const handler = createSendTopicNotificationHandler({
    database,
    messaging: { send: async (message) => sent.push(message) },
    loadCopies: loadNotificationCopies,
  });
  const copies = await loadNotificationCopies();

  await handler({
    auth: { uid: 'personal-1', token: { staff: true } },
    data: { topic: 'cafeteria_menu' },
  });

  assert.equal(sent[0].topic, 'cafeteria_menu');
  assert.equal(sent[0].notification.body, copies.cafeteria_menu.cuerpo);
  const inboxItems = Object.entries(database.values).filter(([path]) =>
    path.startsWith('notificationInbox/usuario-1/'),
  );
  assert.equal(inboxItems.length, 1);
  assert.equal(inboxItems[0][1].type, 'cafeteria_menu');
  await assert.rejects(
    handler({
      auth: { uid: 'personal-1', token: { staff: true } },
      data: { topic: 'cafeteria_avisos', customText: 'Aviso general' },
    }),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
});

test('el texto propio solo admite hasta 120 caracteres y no admite emojis', async () => {
  const sent = [];
  const handler = createSendTopicNotificationHandler({
    database: new FakeDatabase({}),
    messaging: { send: async (message) => sent.push(message) },
    loadCopies: loadNotificationCopies,
  });
  const request = (customText) =>
    handler({
      auth: { uid: 'admin-1', token: { admin: true } },
      data: { topic: 'cafeteria_avisos', customText },
    });

  await assert.rejects(
    request('x'.repeat(121)),
    (error) => error instanceof AppError && error.code === 'invalid-argument',
  );
  await assert.rejects(
    request('Aviso nuevo 🙂'),
    (error) => error instanceof AppError && error.code === 'invalid-argument',
  );
  await assert.rejects(
    request('Escribe a persona@example.com'),
    (error) => error instanceof AppError && error.code === 'invalid-argument',
  );
  await assert.rejects(
    request('Tu folio: LF-1234'),
    (error) => error instanceof AppError && error.code === 'invalid-argument',
  );
  await assert.rejects(
    request('Promoción de $120'),
    (error) => error instanceof AppError && error.code === 'invalid-argument',
  );
  assert.deepEqual(sent, []);
});

test('la recomendación del personal se publica en ofertas como notificación', async () => {
  const sent = [];
  const database = new FakeDatabase({
    notificationPreferences: {
      'usuario-1': { cafeteria_ofertas: true },
    },
  });
  const handler = createSendRecommendationHandler({
    database,
    messaging: { send: async (message) => sent.push(message) },
    loadCopies: loadNotificationCopies,
  });

  await handler({
    auth: { uid: 'staff-1', token: { staff: true } },
    data: { text: 'Prueba el nuevo menú de temporada' },
  });

  assert.equal(sent[0].topic, 'cafeteria_ofertas');
  assert.equal(sent[0].notification.body, 'Prueba el nuevo menú de temporada');
  assert.deepEqual(sent[0].data, { type: 'cafeteria_ofertas' });
  const inboxItems = Object.entries(database.values).filter(([path]) =>
    path.startsWith('notificationInbox/usuario-1/'),
  );
  assert.equal(inboxItems.length, 1);
  assert.equal(
    inboxItems[0][1].body,
    'Prueba el nuevo menú de temporada',
  );
});

test('la recomendación rechaza texto largo, emojis, datos personales y usuarios sin claim', async () => {
  const sent = [];
  const handler = createSendRecommendationHandler({
    database: new FakeDatabase({}),
    messaging: { send: async (message) => sent.push(message) },
    loadCopies: loadNotificationCopies,
  });
  const send = (text, token = { admin: true }) => handler({
    auth: { uid: 'staff-1', token },
    data: { text },
  });

  for (const text of [
    'x'.repeat(121),
    'Oferta 🙂',
    'Escribe a persona@example.com',
    'Pedido #1234',
    'Oferta a $99 MXN',
  ]) {
    await assert.rejects(
      send(text),
      (error) => error instanceof AppError && error.code === 'invalid-argument',
    );
  }
  await assert.rejects(
    send('Oferta de temporada', {}),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
  assert.deepEqual(sent, []);
});

function createOrderHandler() {
  const sent = [];
  const database = new FakeDatabase({
    'notificationTokens/usuario-1': {
      hashValido: { token: 'token-valido' },
    },
  });
  const handler = createOrderStatusNotificationHandler({
    database,
    messaging: {
      async sendEachForMulticast(message) {
        sent.push(message);
        return { successCount: 1, responses: [{ success: true }] };
      },
    },
    loadCopies: loadNotificationCopies,
  });
  return { handler, sent, database };
}

function orderEvent(before, after) {
  return {
    params: { orderId: 'pedido-1' },
    data: {
      before: { val: () => before },
      after: { val: () => after },
    },
  };
}

class FakeDatabase {
  constructor(values) {
    this.values = values;
    this.removed = [];
  }

  ref(path) {
    return {
      get: async () => ({ val: () => this.values[path] ?? null }),
      transaction: async (update) => {
        const current = this.values[path] ?? null;
        const next = update(current);
        if (next === undefined) {
          return { committed: false, snapshot: { val: () => current } };
        }
        this.values[path] = next;
        return { committed: true, snapshot: { val: () => next } };
      },
      remove: async () => {
        this.removed.push(path);
        delete this.values[path];
      },
    };
  }
}

test('cambio a confirmed y a delivered disparan su aviso al dueño del pedido', async () => {
  const { handler, sent } = createOrderHandler();
  await handler(orderEvent(
    { status: 'paid', ownerUid: 'usuario-1' },
    { status: 'confirmed', ownerUid: 'usuario-1' },
  ));
  await handler(orderEvent(
    { status: 'ready', ownerUid: 'usuario-1' },
    { status: 'delivered', ownerUid: 'usuario-1' },
  ));

  assert.deepEqual(sent.map((message) => message.data.type), [
    'pedido_confirmado',
    'pedido_entregado',
  ]);
});

test('un cambio de estado sin aviso asociado no envía nada', async () => {
  const { handler, sent } = createOrderHandler();
  await handler(orderEvent(
    { status: 'preparing', ownerUid: 'usuario-1' },
    { status: 'ready', ownerUid: 'usuario-1', readyAt: 5 },
  ));
  await handler(orderEvent(
    { status: 'ready', ownerUid: 'usuario-1' },
    { status: 'incident', ownerUid: 'usuario-1' },
  ));

  assert.deepEqual(sent.map((message) => message.data.type), ['pedido_listo']);
});

test('el topic de consejos acepta envío del personal con el texto del seed', async () => {
  const sent = [];
  const handler = createSendTopicNotificationHandler({
    database: new FakeDatabase({
      notificationPreferences: { 'usuario-1': { cafeteria_consejos: true } },
    }),
    messaging: { send: async (message) => sent.push(message) },
    loadCopies: loadNotificationCopies,
  });

  await handler({
    auth: { uid: 'staff-1', token: { staff: true } },
    data: { topic: 'cafeteria_consejos' },
  });

  assert.equal(sent.length, 1);
  assert.equal(sent[0].topic, 'cafeteria_consejos');
});
