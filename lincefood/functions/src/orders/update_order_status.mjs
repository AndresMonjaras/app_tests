import { getDatabase } from 'firebase-admin/database';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppError } from '../app_error.mjs';
import { createUpdateOrderStatusHandler } from './update_order_status_handler.mjs';

export const updateOrderStatus = onCall(
  { region: 'us-central1' },
  async (request) => {
    try {
      return await createUpdateOrderStatusHandler({ database: getDatabase() })(
        request,
      );
    } catch (error) {
      if (error instanceof AppError) {
        throw new HttpsError(error.code, error.message);
      }
      throw new HttpsError(
        'internal',
        'No se pudo completar la operación. Inténtalo de nuevo.',
      );
    }
  },
);
