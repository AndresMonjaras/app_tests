import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { get, ref, set } from 'firebase/database';

const projectId = 'lincefood-app';
let testEnvironment;

before(async () => {
  const rules = await readFile(
    new URL('../firebase/database.rules.json', import.meta.url),
    'utf8',
  );

  testEnvironment = await initializeTestEnvironment({
    projectId,
    database: {
      rules,
      host: '127.0.0.1',
      port: 9000,
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearDatabase();
});

after(async () => {
  await testEnvironment?.cleanup();
});

describe('reglas de Realtime Database para notificaciones', () => {
  it('limita los tokens al dueño y no permite leerlos desde el cliente', async () => {
    const ownerDatabase = testEnvironment.authenticatedContext('owner').database();
    const token = {
      token: 'fcm-token',
      platform: 'android',
      updatedAt: 123,
    };

    await assertSucceeds(
      set(ref(ownerDatabase, 'notificationTokens/owner/hash-1'), token),
    );
    await assertFails(get(ref(ownerDatabase, 'notificationTokens/owner')));
    await assertFails(
      set(ref(ownerDatabase, 'notificationTokens/other/hash-1'), token),
    );
    await assertFails(
      set(ref(ownerDatabase, 'notificationTokens/owner/hash-2'), {
        ...token,
        extra: true,
      }),
    );
    await assertFails(
      set(ref(ownerDatabase, 'notificationTokens/owner/hash-3'), {
        ...token,
        platform: 'ios',
      }),
    );
  });

  it('permite al usuario leer su inbox y cambiar solo isRead', async () => {
    const record = {
      type: 'pedido_listo',
      title: 'Pedido listo',
      body: 'Puedes recogerlo.',
      orderId: 'pedido-1',
      createdAt: 123,
      isRead: false,
    };
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await set(
        ref(context.database(), 'notificationInbox/owner/event-1'),
        record,
      );
    });

    const ownerDatabase = testEnvironment.authenticatedContext('owner').database();
    const otherDatabase = testEnvironment.authenticatedContext('other').database();
    const itemPath = 'notificationInbox/owner/event-1';

    await assertSucceeds(get(ref(ownerDatabase, itemPath)));
    await assertFails(get(ref(otherDatabase, itemPath)));
    await assertSucceeds(set(ref(ownerDatabase, `${itemPath}/isRead`), true));
    await assertFails(set(ref(ownerDatabase, `${itemPath}/title`), 'Cambio'));
    await assertFails(
      set(ref(ownerDatabase, `${itemPath}/otro`), 'dato'),
    );
    await assertFails(
      set(ref(otherDatabase, `${itemPath}/isRead`), true),
    );
  });

  it('limita las preferencias a los temas admitidos y valores booleanos', async () => {
    const ownerDatabase = testEnvironment.authenticatedContext('owner').database();
    const preferencesPath = 'notificationPreferences/owner';

    await assertSucceeds(
      set(ref(ownerDatabase, preferencesPath), {
        cafeteria_menu: true,
        cafeteria_ofertas: false,
        cafeteria_avisos: false,
        consejos_cafeteria: true,
      }),
    );
    await assertFails(
      set(ref(ownerDatabase, preferencesPath), {
        cafeteria_menu: true,
        otro_tema: true,
      }),
    );
    await assertFails(
      set(ref(ownerDatabase, preferencesPath), {
        cafeteria_menu: 'sí',
      }),
    );
  });
});

describe('rutas privadas y catálogo', () => {
  it('deniega lectura y escritura de rutas privadas a clientes', async () => {
    const customerDatabase = testEnvironment.authenticatedContext('owner').database();
    const staffDatabase = testEnvironment.authenticatedContext('staff', { staff: true }).database();
    const privatePaths = [
      'payments/order-1',
      'pickupTokens/token-1',
      'staffQueue/order-1',
      'pickupDeliveries/order-1',
      'memberships/owner',
      'pickupSlots/slot-1',
    ];

    for (const path of privatePaths) {
      await assertFails(get(ref(customerDatabase, path)));
      await assertFails(set(ref(customerDatabase, path), { value: true }));
    }

    await assertFails(get(ref(staffDatabase, 'pickupDeliveries/order-1')));
    await assertFails(get(ref(customerDatabase, 'orderEvents/order-1')));
    await assertSucceeds(get(ref(staffDatabase, 'orderEvents/order-1')));
    const adminDatabase = testEnvironment.authenticatedContext('admin', { admin: true }).database();
    await assertFails(get(ref(customerDatabase, 'orderEvents/order-1')));
    await assertSucceeds(get(ref(adminDatabase, 'orderEvents/order-1')));
  });

  it('solo el dueño lee los avisos de rechazo y ningún cliente los escribe', async () => {
    const path = 'rejectionNotices/owner/order-1';
    const notice = { rejectionReason: 'Producto agotado', rejectedAt: 1, expiresAt: 600001 };
    await testEnvironment.withSecurityRulesDisabled((context) =>
      set(ref(context.database(), path), notice),
    );
    const owner = testEnvironment.authenticatedContext('owner').database();
    await assertSucceeds(get(ref(owner, path)));
    await assertFails(set(ref(owner, path), null));

    for (const context of [
      testEnvironment.unauthenticatedContext(),
      testEnvironment.authenticatedContext('other'),
      testEnvironment.authenticatedContext('staff', { staff: true }),
      testEnvironment.authenticatedContext('admin', { admin: true }),
    ]) {
      const database = context.database();
      await assertFails(get(ref(database, path)));
      await assertFails(set(ref(database, path), notice));
    }
  });

  it('personal y administración pueden consultar la cola y el pedido sin escribir', async () => {
    for (const claims of [{ staff: true }, { admin: true }]) {
      const database = testEnvironment.authenticatedContext('operator', claims).database();
      for (const path of ['staffQueue', 'orders/order-1']) {
        await assertSucceeds(get(ref(database, path)));
        await assertFails(set(ref(database, path), true));
      }
    }
    const student = testEnvironment.authenticatedContext('student').database();
    await assertFails(get(ref(student, 'staffQueue')));
    await assertFails(get(ref(student, 'orders/order-1')));
  });

  it('impide al cliente modificar pedidos e índices, incluso estados', async () => {
    const customerDatabase = testEnvironment.authenticatedContext('owner').database();
    await assertFails(set(ref(customerDatabase, 'orders/order-1/status'), 'ready'));
    await assertFails(set(ref(customerDatabase, 'ordersByUser/owner/order-1'), true));
  });

  it('reserva catálogo para lectura autenticada y escritura administrativa', async () => {
    const customerDatabase = testEnvironment.authenticatedContext('owner').database();
    const staffDatabase = testEnvironment.authenticatedContext('staff', { staff: true }).database();
    const adminDatabase = testEnvironment.authenticatedContext('admin', { admin: true }).database();
    const product = {
      name: 'Prueba', categoryId: 'breakfast', priceCents: 1000,
      available: true, prepMinutes: 5,
    };

    await assertSucceeds(get(ref(customerDatabase, 'products')));
    await assertFails(set(ref(customerDatabase, 'products/test'), product));
    await assertFails(set(ref(customerDatabase, 'categories/test'), { name: 'Prueba' }));
    await assertFails(set(ref(staffDatabase, 'categories/test'), { name: 'Prueba' }));
    await assertSucceeds(set(ref(adminDatabase, 'products/test'), product));
    await assertSucceeds(set(ref(adminDatabase, 'categories/test'), { name: 'Prueba' }));
    await assertFails(set(ref(adminDatabase, 'products/test'), { ...product, available: 'sí' }));
    await assertFails(set(ref(adminDatabase, 'products/test'), { ...product, priceCents: 1.5 }));
    await assertFails(set(ref(adminDatabase, 'products/test'), { ...product, priceCents: -1 }));
  });

  it('restringe cafeteria al administrador y valida coordenadas', async () => {
    const staffDatabase = testEnvironment.authenticatedContext('staff', { staff: true }).database();
    const adminDatabase = testEnvironment.authenticatedContext('admin', { admin: true }).database();
    await assertFails(set(ref(staffDatabase, 'cafeteria/name'), 'Otra'));
    await assertSucceeds(set(ref(adminDatabase, 'cafeteria/location/latitude'), 20.5));
    await assertFails(set(ref(adminDatabase, 'cafeteria/location/latitude'), 91));
    await assertSucceeds(set(ref(adminDatabase, 'cafeteria/location/longitude'), -100.8));
    await assertFails(set(ref(adminDatabase, 'cafeteria/location/longitude'), -181));
  });
});

describe('reglas de historial oculto', () => {
  it('admite solo booleanos del dueño y oculta únicamente pedidos terminados', async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const database = context.database();
      await set(ref(database, 'ordersByUser/owner'), {
        done: { status: 'delivered' },
        active: { status: 'ready' },
        rejected: { status: 'rejected' },
        cancelled: { estado: 'cancelado' },
      });
    });
    const owner = testEnvironment.authenticatedContext('owner').database();
    const other = testEnvironment.authenticatedContext('other', { admin: true }).database();
    const hidden = ref(owner, 'hiddenOrders/owner');

    for (const id of ['done', 'rejected', 'cancelled']) {
      await assertSucceeds(set(ref(owner, `hiddenOrders/owner/${id}`), true));
    }
    assert.deepEqual((await assertSucceeds(get(hidden))).val(), {
      cancelled: true, done: true, rejected: true,
    });
    await assertFails(get(ref(other, 'hiddenOrders/owner')));
    await assertFails(set(ref(other, 'hiddenOrders/owner/done'), false));
    await assertFails(set(ref(owner, 'hiddenOrders/owner/done'), 'true'));
    await assertFails(set(ref(owner, 'hiddenOrders/owner/active'), true));
    await assertFails(set(ref(owner, 'hiddenOrders/owner/missing'), true));
    await assertSucceeds(set(ref(owner, 'hiddenOrders/owner/done'), null));
    assert.equal((await get(ref(owner, 'hiddenOrders/owner/done'))).exists(), false);
    assert.equal((await get(ref(owner, 'ordersByUser/owner/done'))).val().status, 'delivered');
  });
});
