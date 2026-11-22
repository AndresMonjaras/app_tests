import { createHash, randomUUID } from 'node:crypto';

export function orderNotificationId(orderId, type) {
  const hash = createHash('sha256')
    .update(`${orderId}:${type}`)
    .digest('hex')
    .slice(0, 32);
  return `order_${hash}`;
}

export function createBroadcastNotificationId() {
  return `broadcast_${randomUUID().replaceAll('-', '')}`;
}

export async function saveNotificationToInbox({
  database,
  uid,
  notificationId,
  type,
  title,
  body,
  createdAt = Date.now(),
  orderId,
}) {
  const notification = {
    type,
    title,
    body,
    createdAt,
    isRead: false,
    ...(orderId == null ? {} : { orderId }),
  };
  const result = await database
    .ref(`notificationInbox/${uid}/${notificationId}`)
    .transaction((current) => {
      if (current == null) return notification;
      // El reintento conserva el texto, la fecha original y la marca de lectura.
      if (type === 'pedido_rechazado' && current.pushFailed === true) {
        return { ...current, pushFailed: null };
      }
      return undefined;
    });
  return result.committed;
}

export async function saveTopicNotificationToInboxes({
  database,
  topic,
  notificationId,
  message,
  createdAt = Date.now(),
}) {
  const snapshot = await database.ref('notificationPreferences').get();
  const preferences = snapshot.val();
  if (!preferences || typeof preferences !== 'object') return 0;

  const recipients = Object.entries(preferences).filter(
    ([, value]) => value?.[topic] === true,
  );
  const results = await Promise.all(
    recipients.map(([uid]) =>
      saveNotificationToInbox({
        database,
        uid,
        notificationId,
        type: topic,
        title: message.notification.title,
        body: message.notification.body,
        createdAt,
      }),
    ),
  );
  return results.filter(Boolean).length;
}

export function recordOrderPushFailure(database, uid, notificationId, type) {
  const entry = database.ref(`notificationInbox/${uid}/${notificationId}`);
  // El estudiante puede consultar el motivo aunque FCM no esté disponible.
  if (type === 'pedido_rechazado') return entry.update({ pushFailed: true });
  return entry.remove();
}
