import test from 'node:test';
import assert from 'node:assert/strict';

import { AppError } from '../src/app_error.mjs';
import { createSyncAvatarEligibilityHandler } from '../src/profile/avatar_eligibility.mjs';

function createAuth(user) {
  const calls = [];
  return {
    calls,
    async getUser(uid) {
      assert.equal(uid, 'student');
      return user;
    },
    async setCustomUserClaims(uid, claims) {
      calls.push({ uid, claims });
    },
  };
}

test('habilita edición de avatar solo para email verificado con proveedor password', async () => {
  const auth = createAuth({
    emailVerified: true,
    providerData: [{ providerId: 'password' }],
    customClaims: { theme: 'dark' },
  });
  const result = await createSyncAvatarEligibilityHandler({ auth })(
    { auth: { uid: 'student', token: { email_verified: true } } },
  );

  assert.deepEqual(result, { avatarEditable: true });
  assert.deepEqual(auth.calls, [{ uid: 'student', claims: { theme: 'dark', avatar_editable: true } }]);
});

test('no concede edición si el correo no está verificado o hay proveedor social vinculado', async () => {
  for (const user of [
    { emailVerified: false, providerData: [{ providerId: 'password' }], customClaims: {} },
    { emailVerified: true, providerData: [{ providerId: 'password' }, { providerId: 'google.com' }], customClaims: {} },
  ]) {
    const auth = createAuth(user);
    const result = await createSyncAvatarEligibilityHandler({ auth })(
      { auth: { uid: 'student', token: { email_verified: true } } },
    );
    assert.deepEqual(result, { avatarEditable: false });
    assert.equal(auth.calls.length, 0);
  }
});

test('retira únicamente el claim de avatar y conserva los demás', async () => {
  const auth = createAuth({
    emailVerified: true,
    providerData: [{ providerId: 'google.com' }],
    customClaims: { staff: true, avatar_editable: true },
  });
  await createSyncAvatarEligibilityHandler({ auth })(
    { auth: { uid: 'student', token: { email_verified: true } } },
  );

  assert.deepEqual(auth.calls, [{ uid: 'student', claims: { staff: true } }]);
});

test('rechaza la solicitud sin autenticación', async () => {
  const auth = createAuth({});
  await assert.rejects(
    createSyncAvatarEligibilityHandler({ auth })({ auth: null }),
    (error) => error instanceof AppError && error.code === 'unauthenticated',
  );
  assert.equal(auth.calls.length, 0);
});
