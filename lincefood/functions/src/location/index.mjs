import { getDatabase } from 'firebase-admin/database';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppError } from '../app_error.mjs';
import {
  createSetCafeteriaLocationHandler,
  createValidateDeliveryLocationHandler,
} from './location_handlers.mjs';

function locationCall(handlerFactory) {
  return onCall({ region: 'us-central1' }, async (request) => {
    try {
      return await handlerFactory({ database: getDatabase() })(request);
    } catch (error) {
      if (error instanceof AppError) throw new HttpsError(error.code, error.message);
      throw new HttpsError('internal', 'No se pudo completar la operación.');
    }
  });
}

export const setCafeteriaLocation = locationCall(createSetCafeteriaLocationHandler);
export const validateDeliveryLocation = locationCall(createValidateDeliveryLocationHandler);
