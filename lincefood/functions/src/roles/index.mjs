import { getAuth } from 'firebase-admin/auth';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

import { AppError } from '../app_error.mjs';
import {
  createSetAdminRoleHandler,
  createSetStaffRoleHandler,
} from './role_handlers.mjs';

const region = 'us-central1';
const bootstrapEmail = defineSecret('ADMIN_BOOTSTRAP_EMAIL');

function withCallableErrors(handlerFactory) {
  return async (request) => {
    try {
      return await handlerFactory()(request);
    } catch (error) {
      if (error instanceof AppError) throw new HttpsError(error.code, error.message);
      throw new HttpsError('internal', 'No se pudo completar la operación.');
    }
  };
}

export const setStaffRole = onCall(
  { region },
  withCallableErrors(() => createSetStaffRoleHandler({ auth: getAuth() })),
);

export const setAdminRole = onCall(
  { region, secrets: [bootstrapEmail] },
  withCallableErrors(() =>
    createSetAdminRoleHandler({
      auth: getAuth(),
      bootstrapEmail: bootstrapEmail.value(),
    }),
  ),
);
