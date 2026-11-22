import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { getDatabase } from 'firebase-admin/database';
import { getMessaging } from 'firebase-admin/messaging';

import { AppError } from '../app_error.mjs';
import { loadNotificationCopies } from './notification_copy.mjs';
import { createSendTopicNotificationHandler } from './send_topic_notification_handler.mjs';

export const sendTopicNotification = onCall(
  { region: 'us-central1' },
  async (request) => {
    try {
      const sendTopicNotificationHandler = createSendTopicNotificationHandler({
        database: getDatabase(),
        messaging: getMessaging(),
        loadCopies: loadNotificationCopies,
      });
      return await sendTopicNotificationHandler(request);
    } catch (error) {
      if (error instanceof AppError) {
        throw new HttpsError(error.code, error.message);
      }
      throw new HttpsError(
        'internal',
        'No se pudo enviar el aviso. Inténtalo de nuevo.',
      );
    }
  },
);
