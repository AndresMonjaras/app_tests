import { getAuth } from 'firebase-admin/auth';
import { getDatabase, ServerValue } from 'firebase-admin/database';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppError } from '../app_error.mjs';
import { createListUsersHandler, createSetUserDisabledHandler } from './user_handlers.mjs';
import {
  createDeactivatePromotionHandler,
  createRevokeScholarshipHandler,
  createUpsertPromotionHandler,
  createUpsertScholarshipHandler,
} from './record_handlers.mjs';

export function adminCallable(factory, options = {}) {
  return onCall(
    { region: 'us-central1', timeoutSeconds: 60, ...options },
    async (request) => {
      try {
        return await factory({
          auth: getAuth(),
          database: getDatabase(),
          serverTimestamp: () => ServerValue.TIMESTAMP,
        })(request);
      } catch (error) {
        if (error instanceof AppError) throw new HttpsError(error.code, error.message);
        if (error.code === 'auth/invalid-page-token') {
          throw new HttpsError('invalid-argument', 'No se pudo continuar la búsqueda.');
        }
        throw new HttpsError('internal', 'No se pudo completar la operación.');
      }
    },
  );
}

export const listUsers = adminCallable(createListUsersHandler);
export const setUserDisabled = adminCallable(createSetUserDisabledHandler);
export const upsertPromotion = adminCallable(createUpsertPromotionHandler);
export const deactivatePromotion = adminCallable(createDeactivatePromotionHandler);
export const upsertScholarship = adminCallable(createUpsertScholarshipHandler);
export const revokeScholarship = adminCallable(createRevokeScholarshipHandler);
