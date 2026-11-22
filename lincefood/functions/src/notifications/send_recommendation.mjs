import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { getDatabase } from 'firebase-admin/database';
import { getMessaging } from 'firebase-admin/messaging';

import { AppError } from '../app_error.mjs';
import { loadNotificationCopies } from './notification_copy.mjs';
import { createSendRecommendationHandler } from './send_recommendation_handler.mjs';

export const sendRecommendation = onCall(
  { region: 'us-central1' },
  async (request) => {
    try {
      return await createSendRecommendationHandler({
        database: getDatabase(),
        messaging: getMessaging(),
        loadCopies: loadNotificationCopies,
      })(request);
    } catch (error) {
      if (error instanceof AppError) {
        throw new HttpsError(error.code, error.message);
      }
      throw new HttpsError(
        'internal',
        'No se pudo enviar la recomendación. Inténtalo de nuevo.',
      );
    }
  },
);
