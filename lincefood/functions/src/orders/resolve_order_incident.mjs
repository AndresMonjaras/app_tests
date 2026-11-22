import { getDatabase } from 'firebase-admin/database';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppError } from '../app_error.mjs';
import { createResolveOrderIncidentHandler } from './resolve_order_incident_handler.mjs';

export const resolveOrderIncident = onCall(
  { region: 'us-central1' },
  async (request) => {
    try {
      return await createResolveOrderIncidentHandler({ database: getDatabase() })(
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
