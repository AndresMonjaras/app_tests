import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createDeactivatePromotionHandler,
  createRevokeScholarshipHandler,
  createUpsertPromotionHandler,
  createUpsertScholarshipHandler,
} from '../src/admin/record_handlers.mjs';
import {
  createListUsersHandler,
  createSetUserDisabledHandler,
} from '../src/admin/user_handlers.mjs';
import { adminRequest, auditEntries, createAdminFakes } from './fixtures/admin_fakes.mjs';

const promotion = {
  title: 'Menú',
  description: 'Precio especial',
  discountPercent: 15,
  active: true,
  startsAt: 100,
  endsAt: 200,
};

test('personal no puede acceder a ninguno de los callables del panel', async () => {
  const deps = createAdminFakes();
  const request = { auth: { uid: 'staff', token: { staff: true } } };
  for (const factory of [
    createDeactivatePromotionHandler, createUpsertPromotionHandler,
    createRevokeScholarshipHandler, createUpsertScholarshipHandler,
    createListUsersHandler, createSetUserDisabledHandler,
  ]) {
    await assert.rejects(factory(deps)(request), (error) => error.code === 'permission-denied');
  }
  assert.deepEqual(deps.state, {});
});

test('listUsers busca por correo y nombre, conserva el cursor y audita sin términos de búsqueda', async () => {
  const deps = createAdminFakes({
    first: { email: 'first@example.test', displayName: 'Estudiante', customClaims: { delivery: true } },
    second: { email: 'estudiante@example.test', disabled: true },
  });
  const list = createListUsersHandler(deps);
  const first = await list(adminRequest({ search: 'ESTUDIANTE', pageSize: 1 }));
  assert.equal(first.users[0].uid, 'first');
  assert.deepEqual(first.users[0].roles, ['delivery_staff']);
  const second = await list(adminRequest({ search: 'estudiante', pageSize: 1, pageToken: first.nextPageToken }));
  assert.equal(second.users[0].uid, 'second');
  assert.equal(second.users[0].disabled, true);
  assert.equal(second.nextPageToken, null);
  assert.equal(auditEntries(deps.state).length, 2);
  assert.ok(!JSON.stringify(auditEntries(deps.state)).includes('estudiante'));
});

test('setUserDisabled rechaza la cuenta propia y audita deshabilitar otra cuenta', async () => {
  const deps = createAdminFakes({ target: {} });
  const handler = createSetUserDisabledHandler(deps);
  await assert.rejects(handler(adminRequest({ uid: 'admin', disabled: true })),
    (error) => error.code === 'failed-precondition');
  await handler(adminRequest({ uid: 'target', disabled: true }));
  assert.equal((await deps.auth.getUser('target')).disabled, true);
  const [event] = auditEntries(deps.state);
  assert.deepEqual(event.before, { disabled: false });
  assert.deepEqual(event.after, { disabled: true });
});

test('promoción requiere fechas ordenadas y un solo descuento en el rango permitido', async () => {
  const deps = createAdminFakes();
  const handler = createUpsertPromotionHandler(deps);
  for (const invalid of [
    { discountPercent: 91 }, { discountPercent: 0 }, { discountCents: 100 }, { endsAt: 100 },
    { active: 'true' }, { title: ' ' }, { discountPercent: undefined, discountCents: 0 },
  ]) {
    await assert.rejects(handler(adminRequest({ ...promotion, ...invalid })),
      (error) => error.code === 'invalid-argument');
  }
  assert.deepEqual(auditEntries(deps.state), []);
});

test('alta, edición y desactivación de promoción registran los cambios sin borrarla', async () => {
  const deps = createAdminFakes();
  const save = createUpsertPromotionHandler(deps);
  const { id } = await save(adminRequest(promotion));
  await save(adminRequest({ ...promotion, id, discountPercent: undefined, discountCents: 200 }));
  await createDeactivatePromotionHandler(deps)(adminRequest({ id }));
  const current = deps.state[`promotions/${id}`];
  const [created, updated, disabled] = auditEntries(deps.state);
  assert.equal(current.active, false);
  assert.ok(!Object.hasOwn(current, 'discountPercent'));
  assert.equal(current.discountCents, 200);
  assert.deepEqual(created.before, { exists: false });
  assert.deepEqual(updated.before, promotion);
  assert.equal(disabled.before.active, true);
  assert.deepEqual(disabled.after, current);
});

test('beca valida tipo y usos, permite cero y registra asignación y revocación', async () => {
  const deps = createAdminFakes({ owner: {} });
  const save = createUpsertScholarshipHandler(deps);
  for (const [type, remainingUses] of [['other', 1], ['meal', -1], ['meal', 1.5]]) {
    await assert.rejects(save(adminRequest({ uid: 'owner', type, remainingUses })),
      (error) => error.code === 'invalid-argument');
  }
  await save(adminRequest({ uid: 'owner', type: 'meal', remainingUses: 2 }));
  await save(adminRequest({ uid: 'owner', type: 'meal', remainingUses: 0 }));
  const current = deps.state['scholarships/owner'];
  assert.deepEqual(current, { type: 'meal', remainingUses: 0, assignedBy: 'admin', updatedAt: 123 });
  await createRevokeScholarshipHandler(deps)(adminRequest({ uid: 'owner' }));
  const [created, updated, revoked] = auditEntries(deps.state);
  assert.deepEqual(created.before, { exists: false });
  assert.equal(updated.before.remainingUses, 2);
  assert.deepEqual(revoked.before, current);
  assert.deepEqual(revoked.after, { exists: false });
  assert.ok(!Object.hasOwn(deps.state, 'scholarships/owner'));
});
