import test from 'node:test';
import assert from 'node:assert/strict';

import { AppError } from '../src/app_error.mjs';
import {
  createSetAdminRoleHandler,
  createSetStaffRoleHandler,
} from '../src/roles/role_handlers.mjs';

function createAuth(users = {}) {
  const claimsSet = [];
  return {
    claimsSet,
    async getUser(uid) {
      const user = users[uid];
      if (!user) throw new Error('user-not-found');
      return user;
    },
    async setCustomUserClaims(uid, claims) {
      claimsSet.push({ uid, claims });
    },
  };
}

test('solo una persona admin puede asignar el claim staff y conserva otros claims', async () => {
  const auth = createAuth({ target: { customClaims: { theme: 'dark' } } });
  const handler = createSetStaffRoleHandler({ auth });
  const result = await handler({
    auth: { uid: 'admin', token: { admin: true } },
    data: { uid: 'target', enabled: true },
  });

  assert.deepEqual(result, { uid: 'target', staff: true });
  assert.deepEqual(auth.claimsSet[0], {
    uid: 'target',
    claims: { theme: 'dark', staff: true },
  });
});

test('setStaffRole rechaza a quien no tiene claim admin', async () => {
  const handler = createSetStaffRoleHandler({ auth: createAuth() });
  await assert.rejects(
    handler({ auth: { uid: 'user', token: { staff: true } }, data: { uid: 'target', enabled: true } }),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
});

test('el correo bootstrap verificado solo puede asignar admin a su propia cuenta', async () => {
  const auth = createAuth({
    bootstrap: { email: 'admin@example.test', emailVerified: true, customClaims: {} },
  });
  const handler = createSetAdminRoleHandler({ auth, bootstrapEmail: 'admin@example.test' });
  const result = await handler({
    auth: { uid: 'bootstrap', token: {} },
    data: { uid: 'bootstrap', enabled: true },
  });

  assert.deepEqual(result, { uid: 'bootstrap', admin: true });
  assert.deepEqual(auth.claimsSet[0], { uid: 'bootstrap', claims: { admin: true } });
});

test('el bootstrap no puede asignar admin a otra cuenta ni usar correo sin verificar', async () => {
  const auth = createAuth({
    bootstrap: { email: 'admin@example.test', emailVerified: true, customClaims: {} },
    other: { email: 'other@example.test', emailVerified: true, customClaims: {} },
  });
  const handler = createSetAdminRoleHandler({ auth, bootstrapEmail: 'admin@example.test' });
  await assert.rejects(
    handler({ auth: { uid: 'bootstrap', token: {} }, data: { uid: 'other', enabled: true } }),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
  auth.getUser = async () => ({ email: 'admin@example.test', emailVerified: false });
  await assert.rejects(
    handler({ auth: { uid: 'bootstrap', token: {} }, data: { uid: 'bootstrap', enabled: true } }),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
});

test('administración no puede retirar su propio permiso', async () => {
  const auth = createAuth({ admin: { customClaims: { admin: true } } });
  await assert.rejects(createSetAdminRoleHandler({ auth })({
    auth: { uid: 'admin', token: { admin: true } }, data: { uid: 'admin', enabled: false },
  }), (error) => error.code === 'failed-precondition');
  assert.equal(auth.claimsSet.length, 0);
});
