import { getDatabase } from 'firebase-admin/database';
import { getMessaging } from 'firebase-admin/messaging';
import { onValueWritten } from 'firebase-functions/v2/database';

import { loadNotificationCopies } from './notification_copy.mjs';
import { createOrderStatusNotificationHandler } from './order_status_notification_handler.mjs';

export const notifyOrderStatus = onValueWritten(
  { ref: '/orders/{orderId}', region: 'us-central1' },
  (event) =>
    createOrderStatusNotificationHandler({
      database: getDatabase(),
      messaging: getMessaging(),
      loadCopies: loadNotificationCopies,
    })(event),
);
