import { getApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

try {
  getApp();
} catch (_) {
  initializeApp();
}

const auth = getAuth();

export const synchronizeAvatarEligibility = onCall(
  {
    region: 'us-central1',
    enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true',
    maxInstances: 2,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }
    if (request.auth.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'Verifica tu correo.');
    }

    const user = await auth.getUser(uid);
    const providers = user.providerData.map((provider) => provider.providerId);
    const avatarEditable =
      user.emailVerified === true &&
      Boolean(user.email) &&
      providers.length === 1 &&
      providers[0] === 'password';

    const claims = { ...(user.customClaims ?? {}) };
    if (avatarEditable) {
      claims.avatar_editable = true;
    } else {
      delete claims.avatar_editable;
    }
    if ((user.customClaims?.avatar_editable === true) !== avatarEditable) {
      await auth.setCustomUserClaims(uid, claims);
    }
    return { avatarEditable };
  },
);
