import { AppError } from '../app_error.mjs';

function requireUid(value) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new AppError('unauthenticated', 'Inicia sesión para continuar.');
  }
  return value;
}

export function createSyncAvatarEligibilityHandler({ auth }) {
  return async (request) => {
    const uid = requireUid(request.auth?.uid);
    const user = await auth.getUser(uid);
    const providers = new Set(
      (user.providerData ?? []).map((provider) => provider.providerId),
    );
    const avatarEditable =
      request.auth.token?.email_verified === true &&
      user.emailVerified === true &&
      providers.size === 1 &&
      providers.has('password');

    const claims = { ...(user.customClaims ?? {}) };
    const previouslyEditable = claims.avatar_editable === true;
    if (avatarEditable) {
      claims.avatar_editable = true;
    } else {
      delete claims.avatar_editable;
    }

    if (previouslyEditable !== avatarEditable) {
      await auth.setCustomUserClaims(uid, claims);
    }

    return { avatarEditable };
  };
}
