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
