import { getAuth } from 'firebase-admin/auth';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppError } from '../app_error.mjs';
import { createSyncAvatarEligibilityHandler } from './avatar_eligibility.mjs';

const region = 'us-central1';

export const synchronizeAvatarEligibility = onCall({ region }, async (request) => {
  try {
    return await createSyncAvatarEligibilityHandler({ auth: getAuth() })(request);
  } catch (error) {
    if (error instanceof AppError) {
      throw new HttpsError(error.code, error.message);
    }
    throw new HttpsError(
      'internal',
      'No se pudo verificar el permiso para cambiar el avatar.',
    );
  }
});
