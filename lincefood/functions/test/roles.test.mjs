import test from 'node:test';
import assert from 'node:assert/strict';

import { AppError } from '../src/app_error.mjs';
import {
  createSetAdminRoleHandler,
  createSetStaffRoleHandler,
  createSetUserRoleHandler,
} from '../src/roles/role_handlers.mjs';

import { adminRequest, auditEntries, createAdminFakes } from './fixtures/admin_fakes.mjs';

test('solo una persona admin puede asignar el claim staff y conserva otros claims', async () => {
  const deps = createAdminFakes({ target: { customClaims: { theme: 'dark' } } });
  const { auth } = deps;
  const handler = createSetStaffRoleHandler(deps);
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
  const handler = createSetStaffRoleHandler(createAdminFakes());
  await assert.rejects(
    handler({ auth: { uid: 'user', token: { staff: true } }, data: { uid: 'target', enabled: true } }),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
});

test('el correo bootstrap verificado solo puede asignar admin a su propia cuenta', async () => {
  const deps = createAdminFakes({
    admin: { disabled: true },
    bootstrap: { email: 'admin@example.test', emailVerified: true, customClaims: {} },
  });
  const { auth } = deps;
  const handler = createSetAdminRoleHandler({ ...deps, bootstrapEmail: 'admin@example.test' });
  const result = await handler({
    auth: { uid: 'bootstrap', token: {} },
    data: { uid: 'bootstrap', enabled: true },
  });

  assert.deepEqual(result, { uid: 'bootstrap', admin: true });
  assert.deepEqual(auth.claimsSet[0], { uid: 'bootstrap', claims: { admin: true } });
});

test('el bootstrap no puede asignar admin a otra cuenta ni usar correo sin verificar', async () => {
  const deps = createAdminFakes({
    admin: { disabled: true },
    bootstrap: { email: 'admin@example.test', emailVerified: true, customClaims: {} },
    other: { email: 'other@example.test', emailVerified: true, customClaims: {} },
  });
  const { auth } = deps;
  const handler = createSetAdminRoleHandler({ ...deps, bootstrapEmail: 'admin@example.test' });
  await assert.rejects(
    handler({ auth: { uid: 'bootstrap', token: {} }, data: { uid: 'other', enabled: true } }),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
  auth.getUser = async (uid) => ({ uid, email: 'admin@example.test', emailVerified: false });
  await assert.rejects(
    handler({ auth: { uid: 'bootstrap', token: {} }, data: { uid: 'bootstrap', enabled: true } }),
    (error) => error instanceof AppError && error.code === 'permission-denied',
  );
});

test('administración no puede retirar su propio permiso', async () => {
  const deps = createAdminFakes();
  const { auth } = deps;
  await assert.rejects(createSetAdminRoleHandler(deps)({
    auth: { uid: 'admin', token: { admin: true } }, data: { uid: 'admin', enabled: false },
  }), (error) => error.code === 'failed-precondition');
  assert.equal(auth.claimsSet.length, 0);
});

test('setUserRole asigna delivery por correo y registra el antes y después', async () => {
  const deps = createAdminFakes({ target: { email: 'target@example.test' } });
  const result = await createSetUserRoleHandler(deps)(adminRequest({
    email: 'target@example.test', role: 'delivery_staff', enabled: true,
  }));
  assert.deepEqual(result, { uid: 'target', delivery: true });
  assert.deepEqual(auditEntries(deps.state), [{
    actorUid: 'admin',
    action: 'setUserRole',
    target: 'target',
    before: { role: 'delivery_staff', enabled: false },
    after: { role: 'delivery_staff', enabled: true },
    at: 123,
  }]);
});

test('solo una cuenta con claim vigente puede cambiar roles', async () => {
  const deps = createAdminFakes({ actor: { customClaims: { staff: true } } });
  const data = { uid: 'admin', role: 'delivery_staff', enabled: true };
  const handler = createSetUserRoleHandler(deps);
  for (const token of [{ staff: true }, { admin: true }]) {
    await assert.rejects(handler({ auth: { uid: 'actor', token }, data }),
      (error) => error.code === 'permission-denied');
  }
  assert.deepEqual(auditEntries(deps.state), []);
});

test('el último admin activo no se puede retirar', async () => {
  const deps = createAdminFakes({ other: { customClaims: { admin: true } } });
  // Simula que el directorio solo devuelve al admin objetivo.
  deps.auth.listUsers = async () => ({ users: [{ uid: 'other', customClaims: { admin: true } }] });
  await assert.rejects(createSetUserRoleHandler(deps)(adminRequest({
    uid: 'other', role: 'superadmin', enabled: false,
  })), (error) => error.code === 'failed-precondition');
  assert.deepEqual(deps.auth.claimsSet, []);
});

test('dos administradores no pueden retirarse el rol al mismo tiempo', async () => {
  const deps = createAdminFakes({ other: { customClaims: { admin: true } } });
  const handler = createSetUserRoleHandler(deps);
  const results = await Promise.allSettled([
    handler(adminRequest({ uid: 'other', role: 'superadmin', enabled: false })),
    handler(adminRequest({ uid: 'admin', role: 'superadmin', enabled: false }, 'other')),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(deps.auth.claimsSet.length, 1);
  assert.equal(auditEntries(deps.state).length, 1);
});

test('el bootstrap legado no concede admin mientras otra cuenta admin esté activa', async () => {
  const deps = createAdminFakes({
    candidate: { email: 'candidate@example.test', emailVerified: true },
  });
  const handler = createSetAdminRoleHandler({ ...deps, bootstrapEmail: 'candidate@example.test' });
  await assert.rejects(handler({
    auth: { uid: 'candidate', token: {} },
    data: { uid: 'candidate', enabled: true },
  }), (error) => error.code === 'permission-denied');
});

test('una cuenta sin autorización de bootstrap no adquiere el bloqueo administrativo', async () => {
  const deps = createAdminFakes({
    candidate: {
      email: 'candidate@example.test',
      emailVerified: true,
      customClaims: { staff: true },
    },
  });
  const handler = createSetAdminRoleHandler({ ...deps, bootstrapEmail: 'candidate@example.test' });
  await assert.rejects(handler({
    auth: { uid: 'candidate', token: { staff: true } },
    data: { uid: 'candidate', enabled: true },
  }), (error) => error.code === 'permission-denied');
  assert.deepEqual(deps.state, {});
});
